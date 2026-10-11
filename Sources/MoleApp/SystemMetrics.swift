import AppKit
import Darwin
import Foundation
import IOKit.ps
import SwiftUI

// ============================================================
// 真实系统指标:全部来自本机读取,不含示意数据
// ============================================================

struct RealProcess: Identifiable {
    let id: Int32
    let name: String
    let memBytes: Int64
    let cpu: Double
}

struct SystemMetrics {
    // ---------------------------------------------------------- CPU

    struct CpuTicks {
        var user: UInt32 = 0
        var system: UInt32 = 0
        var idle: UInt32 = 0
        var nice: UInt32 = 0
    }

    static func cpuTicks() -> CpuTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CpuTicks(
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            idle: info.cpu_ticks.2,
            nice: info.cpu_ticks.3
        )
    }

    static func cpuUsage(from previous: CpuTicks, to current: CpuTicks) -> Double {
        let userDelta = Double(current.user &- previous.user)
        let systemDelta = Double(current.system &- previous.system)
        let niceDelta = Double(current.nice &- previous.nice)
        let idleDelta = Double(current.idle &- previous.idle)
        let total = userDelta + systemDelta + niceDelta + idleDelta
        guard total > 0 else { return 0 }
        return ((userDelta + systemDelta + niceDelta) / total) * 100
    }

    // ---------------------------------------------------------- 内存

    struct MemoryInfo {
        var usedBytes: UInt64
        var totalBytes: UInt64
        var swapUsedBytes: UInt64
        var swapTotalBytes: UInt64
    }

    static func memoryInfo() -> MemoryInfo? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let total = ProcessInfo.processInfo.physicalMemory
        let used = min(total, active + wired + compressed)

        var swapUsed: UInt64 = 0
        var swapTotal: UInt64 = 0
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 {
            swapUsed = usage.xsu_used
            swapTotal = usage.xsu_total
        }
        return MemoryInfo(
            usedBytes: used,
            totalBytes: total,
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal
        )
    }

    // ---------------------------------------------------------- 磁盘

    struct DiskInfo {
        var usedBytes: UInt64
        var totalBytes: UInt64
    }

    static func diskInfo() -> DiskInfo? {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attributes[.systemSize] as? NSNumber,
              let free = attributes[.systemFreeSize] as? NSNumber else { return nil }
        let totalBytes = total.uint64Value
        let freeBytes = free.uint64Value
        return DiskInfo(usedBytes: totalBytes - min(freeBytes, totalBytes), totalBytes: totalBytes)
    }

    // ---------------------------------------------------------- 网络

    static func networkBytes() -> (received: UInt64, sent: UInt64) {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return (0, 0) }
        defer { freeifaddrs(addresses) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let interface = current.pointee
            if let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.ifa_data {
                let name = String(cString: interface.ifa_name)
                if name != "lo0" {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    received += UInt64(stats.ifi_ibytes)
                    sent += UInt64(stats.ifi_obytes)
                }
            }
            pointer = interface.ifa_next
        }
        return (received, sent)
    }

    // ---------------------------------------------------------- GPU(IOAccelerator)

    static func gpuUsage() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator
        ) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var best: Double?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                for key in ["Device Utilization %", "GPU Activity(%)", "Renderer Utilization %"] {
                    if let value = perf[key] as? Int {
                        best = max(best ?? 0, Double(value))
                        break
                    }
                    if let value = perf[key] as? Double {
                        best = max(best ?? 0, value)
                        break
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return best
    }

    // ---------------------------------------------------------- SMC(温度 / 风扇,只读)

    struct ThermalInfo {
        var temperature: Double?
        var fanRPM: Double?
    }

    final class SMCReader {
        private var connection: io_connect_t = 0

        init?() {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
            guard service != 0 else { return nil }
            defer { IOObjectRelease(service) }
            guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
                return nil
            }
        }

        deinit {
            if connection != 0 { IOServiceClose(connection) }
        }

        struct Reading {
            let type: String
            let bytes: [UInt8]
        }

        func read(_ name: String) -> Reading? {
            var info = SMCKeyData()
            var output = SMCKeyData()
            info.key = Self.fourCC(name)
            info.data8 = 9 // SMC_CMD_READ_KEYINFO
            var outSize = MemoryLayout<SMCKeyData>.size
            guard IOConnectCallStructMethod(
                connection, 2, &info, MemoryLayout<SMCKeyData>.size, &output, &outSize
            ) == KERN_SUCCESS, output.result == 0 else { return nil }

            var request = SMCKeyData()
            request.key = info.key
            request.keyInfo.dataSize = output.keyInfo.dataSize
            request.data8 = 5 // SMC_CMD_READ_BYTES
            var bytesOut = SMCKeyData()
            var bytesSize = MemoryLayout<SMCKeyData>.size
            guard IOConnectCallStructMethod(
                connection, 2, &request, MemoryLayout<SMCKeyData>.size, &bytesOut, &bytesSize
            ) == KERN_SUCCESS, bytesOut.result == 0 else { return nil }

            let raw = withUnsafeBytes(of: bytesOut.bytes) { Array($0) }
            let size = min(Int(output.keyInfo.dataSize), raw.count)
            let type = output.keyInfo.dataType
            let typeString = String(bytes: [
                UInt8((type >> 24) & 0xFF), UInt8((type >> 16) & 0xFF),
                UInt8((type >> 8) & 0xFF), UInt8(type & 0xFF),
            ], encoding: .ascii) ?? "?"
            return Reading(type: typeString, bytes: Array(raw.prefix(size)))
        }

        /// flt:小端 Float32(Apple Silicon 的 TpXX 温度键在用)
        func floatValue(_ name: String) -> Double? {
            guard let reading = read(name), reading.type == "flt", reading.bytes.count == 4 else {
                return nil
            }
            let b = reading.bytes
            let bits = UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
            return Double(Float(bitPattern: bits))
        }

        /// fpe2:大端 16 位除以 4(经典风扇键)
        func fpe2Value(_ name: String) -> Double? {
            guard let reading = read(name), reading.type == "fpe2", reading.bytes.count >= 2 else {
                return nil
            }
            let raw = UInt16(reading.bytes[0]) << 8 | UInt16(reading.bytes[1])
            return Double(raw) / 4.0
        }

        private static func fourCC(_ string: String) -> UInt32 {
            var value: UInt32 = 0
            for byte in string.utf8 { value = (value << 8) | UInt32(byte) }
            return value
        }
    }

    // SMC 结构按 C 头文件的字段顺序与类型排布,让内核按原布局读取。
    struct SMCKeyDataVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    struct SMCKeyDataPLimit {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpu: UInt32 = 0
        var gpu: UInt32 = 0
        var mem: UInt32 = 0
    }

    struct SMCKeyDataKeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
        var pad: (UInt8, UInt8, UInt8) = (0, 0, 0)
    }

    struct SMCKeyData {
        var key: UInt32 = 0
        var vers = SMCKeyDataVersion()
        var pLimit = SMCKeyDataPLimit()
        var keyInfo = SMCKeyDataKeyInfo()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
        ) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    static func thermalInfo() -> ThermalInfo {
        guard let smc = SMCReader() else { return ThermalInfo() }
        var temperature: Double?
        for key in ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0P", "TC0P", "TC0D", "Te05"] {
            if let value = smc.floatValue(key), value > 5, value < 120 {
                temperature = value
                break
            }
        }
        var fan: Double?
        for key in ["F0Ac", "F0Mn"] {
            if let value = smc.fpe2Value(key), value >= 0, value < 20000 {
                fan = value
                break
            }
            if let value = smc.floatValue(key), value >= 0, value < 20000 {
                fan = value
                break
            }
        }
        return ThermalInfo(temperature: temperature, fanRPM: fan)
    }

    // ---------------------------------------------------------- 负载 / 芯片 / 电池

    static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        _ = getloadavg(&loads, 3)
        return loads
    }

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    struct BatteryInfo {
        let percent: Int
        let charging: Bool
        let onAC: Bool
    }

    static func battery() -> BatteryInfo? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard let current = description[kIOPSCurrentCapacityKey as String] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
                  maxCapacity > 0 else { continue }
            let charging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false
            let onAC = (description[kIOPSPowerSourceStateKey as String] as? String)
                == (kIOPSACPowerValue as String)
            return BatteryInfo(percent: Int(Double(current) / Double(maxCapacity) * 100), charging: charging, onAC: onAC)
        }
        return nil
    }

    // ---------------------------------------------------------- 进程

    static func topProcesses(limit: Int = 8) -> [RealProcess] {
        let result = CommandRunner.runSync("/bin/ps", ["-axo", "pid=,pcpu=,rss=,comm="], timeout: 3)
        guard result.code == 0 else { return [] }
        let output = result.output

        var rows: [RealProcess] = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = Int64(parts[2]) else { continue }
            let command = String(parts[3])
            let name = URL(fileURLWithPath: command).lastPathComponent
            guard !name.isEmpty else { continue }
            rows.append(RealProcess(id: pid, name: name, memBytes: rssKB * 1024, cpu: cpu))
        }
        return rows.sorted { $0.memBytes > $1.memBytes }.prefix(limit).map { $0 }
    }
}

// ============================================================
// 视图状态:每 1.5 秒采样一次,维护两条迷你曲线
// ============================================================

@MainActor
final class StatusStore: ObservableObject {
    @Published private(set) var cpu = 0.0
    @Published private(set) var hasCPUReading = false
    @Published private(set) var memPercent = 0.0
    @Published private(set) var memUsedText = "—"
    @Published private(set) var swapText = "—"
    @Published private(set) var diskPercent = 0.0
    @Published private(set) var diskUsedText = "—"
    @Published private(set) var diskFreeText = "—"
    @Published private(set) var downRate = 0.0
    @Published private(set) var upRate = 0.0
    @Published private(set) var load: [Double] = [0, 0, 0]
    @Published private(set) var battery: SystemMetrics.BatteryInfo?
    @Published private(set) var gpu: Double?
    @Published private(set) var temperature: Double?
    @Published private(set) var fanRPM: Double?
    @Published private(set) var processes: [RealProcess] = []
    @Published private(set) var cpuHistory: [Double] = Array(repeating: 0, count: 42)
    @Published private(set) var netHistory: [Double] = Array(repeating: 0, count: 42)
    @Published private(set) var gpuHistory: [Double] = Array(repeating: 0, count: 42)

    let hostName: String = Host.current().localizedName ?? "Mac"
    let chip: String = SystemMetrics.sysctlString("machdep.cpu.brand_string") ?? "—"
    let coreCount = ProcessInfo.processInfo.activeProcessorCount
    let memoryGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
    let osVersion: String = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion)"
    }()

    private var timer: Timer?
    private var tick = 0
    private var sampling = false
    private var sampleTask: Task<Void, Never>?
    private var generation = 0
    private var previousTicks: SystemMetrics.CpuTicks?
    private var previousNetwork: (received: UInt64, sent: UInt64)?

    var uptimeText: String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "\(days) 天 \(hours) 小时" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
        return "\(minutes) 分"
    }

    var bootDateText: String {
        let boot = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter.string(from: boot)
    }

    var healthScore: Int {
        var score = 100
        if memPercent > 85 { score -= 20 } else if memPercent > 75 { score -= 10 }
        if diskPercent > 92 { score -= 20 } else if diskPercent > 85 { score -= 10 }
        if cpu > 85 { score -= 10 } else if cpu > 70 { score -= 5 }
        return max(60, score)
    }

    var healthText: String {
        switch healthScore {
        case 90...: "负载平稳"
        case 75..<90: "负载较高"
        default: "建议关注"
        }
    }

    func start() {
        guard timer == nil else { return }
        generation += 1
        previousTicks = nil
        previousNetwork = nil
        previousMonotonicTime = nil
        downRate = 0
        upRate = 0
        hasCPUReading = false
        tick = 0
        tickOnce()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickOnce() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        generation += 1
        sampleTask?.cancel()
        sampling = false
    }

    /// 硬件、文件系统和进程读取全部在后台，主线程只发布这一帧结果。
    private struct Snapshot {
        let ticks: SystemMetrics.CpuTicks?
        let memory: SystemMetrics.MemoryInfo?
        let network: (received: UInt64, sent: UInt64)
        let time: TimeInterval
        let load: [Double]
        var disk: SystemMetrics.DiskInfo?
        var battery: SystemMetrics.BatteryInfo?
        var gpu: Double?
        var thermal: SystemMetrics.ThermalInfo?
        var processes: [RealProcess]?
    }

    private func tickOnce() {
        guard !sampling else { return }
        tick += 1
        sampling = true
        let revision = generation
        let heavy = tick % 4 == 1
        sampleTask = Task { [weak self] in
            let worker = Task.detached(priority: .utility) {
                var frame = Snapshot(ticks: SystemMetrics.cpuTicks(), memory: SystemMetrics.memoryInfo(),
                                     network: SystemMetrics.networkBytes(), time: ProcessInfo.processInfo.systemUptime,
                                     load: SystemMetrics.loadAverage())
                if heavy && !Task.isCancelled {
                    frame.disk = SystemMetrics.diskInfo()
                    frame.battery = SystemMetrics.battery()
                    frame.gpu = SystemMetrics.gpuUsage()
                    frame.thermal = SystemMetrics.thermalInfo()
                    if !Task.isCancelled { frame.processes = SystemMetrics.topProcesses() }
                }
                return frame
            }
            let frame = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
            guard let self, !Task.isCancelled, self.generation == revision else { return }
            self.apply(frame, heavy: heavy)
            self.sampling = false
        }
    }

    private var previousMonotonicTime: TimeInterval?

    private func apply(_ frame: Snapshot, heavy: Bool) {
        if let current = frame.ticks {
            if let previous = previousTicks {
                cpu = SystemMetrics.cpuUsage(from: previous, to: current)
                hasCPUReading = true
                cpuHistory = shift(cpuHistory, appending: cpu)
            }
            previousTicks = current
        }
        load = frame.load
        if let memory = frame.memory {
            memPercent = Double(memory.usedBytes) / Double(memory.totalBytes) * 100
            memUsedText = format(memory.usedBytes) + " / " + format(memory.totalBytes)
            swapText = "交换空间 " + format(memory.swapUsedBytes)
        }
        if let previous = previousNetwork, let previousTime = previousMonotonicTime {
            let seconds = max(0.1, frame.time - previousTime)
            // 接口消失、重置或计数回绕不能用无符号减法变成巨大的网速。
            downRate = Self.counterRate(current: frame.network.received, previous: previous.received, seconds: seconds)
            upRate = Self.counterRate(current: frame.network.sent, previous: previous.sent, seconds: seconds)
        }
        previousNetwork = frame.network
        previousMonotonicTime = frame.time
        netHistory = shift(netHistory, appending: downRate)
        if heavy {
            if let disk = frame.disk, disk.totalBytes > 0 {
                diskPercent = Double(disk.usedBytes) / Double(disk.totalBytes) * 100
                diskUsedText = "已用 " + format(disk.usedBytes)
                diskFreeText = format(disk.totalBytes - disk.usedBytes)
            }
            battery = frame.battery
            gpu = frame.gpu
            if let value = gpu { gpuHistory = shift(gpuHistory, appending: value) }
            temperature = frame.thermal?.temperature
            fanRPM = frame.thermal?.fanRPM
            if let processes = frame.processes { self.processes = processes }
        }
    }

    nonisolated static func counterRate(current: UInt64, previous: UInt64, seconds: TimeInterval) -> Double {
        guard current >= previous, seconds > 0 else { return 0 }
        return Double(current - previous) / seconds
    }

    private func shift(_ history: [Double], appending value: Double) -> [Double] {
        var next = history
        next.removeFirst()
        next.append(value)
        return next
    }

    private func format(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    func formatRate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        }
        return String(format: "%.0f KB/s", bytesPerSecond / 1024)
    }
}
