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
        return DiskInfo(usedBytes: totalBytes - freeBytes, totalBytes: totalBytes)
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

    static func battery() -> (percent: Int, charging: Bool)? {
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
            return (Int(Double(current) / Double(maxCapacity) * 100), charging || onAC)
        }
        return nil
    }

    // ---------------------------------------------------------- 进程

    static func topProcesses(limit: Int = 8) -> [RealProcess] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid=,pcpu=,rss=,comm="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

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
    @Published private(set) var memPercent = 0.0
    @Published private(set) var memUsedText = "—"
    @Published private(set) var swapText = "—"
    @Published private(set) var diskPercent = 0.0
    @Published private(set) var diskUsedText = "—"
    @Published private(set) var diskFreeText = "—"
    @Published private(set) var downRate = 0.0
    @Published private(set) var upRate = 0.0
    @Published private(set) var load: [Double] = [0, 0, 0]
    @Published private(set) var battery: (percent: Int, charging: Bool)?
    @Published private(set) var processes: [RealProcess] = []
    @Published private(set) var cpuHistory: [Double] = Array(repeating: 0, count: 42)
    @Published private(set) var netHistory: [Double] = Array(repeating: 0, count: 42)

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
    private var previousTicks: SystemMetrics.CpuTicks?
    private var previousNetwork: (received: UInt64, sent: UInt64)?
    private var previousNetworkTime: Date?
    private var previousDisk: SystemMetrics.DiskInfo?

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
        case 90...: "很好"
        case 75..<90: "良好"
        default: "注意"
        }
    }

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickOnce() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tickOnce() {
        tick += 1
        sample()
    }

    private func sample() {
        if let current = SystemMetrics.cpuTicks() {
            if let previous = previousTicks {
                cpu = SystemMetrics.cpuUsage(from: previous, to: current)
            }
            previousTicks = current
        }
        cpuHistory = shift(cpuHistory, appending: cpu)

        let shouldDoHeavy = previousDisk == nil || tick % 2 == 0
        guard shouldDoHeavy else {
            load = SystemMetrics.loadAverage()
            return
        }

        if let memory = SystemMetrics.memoryInfo() {
            memPercent = Double(memory.usedBytes) / Double(memory.totalBytes) * 100
            memUsedText = format(memory.usedBytes) + " / " + format(memory.totalBytes)
            swapText = "交换空间 " + format(memory.swapUsedBytes)
        }
        if let disk = SystemMetrics.diskInfo() {
            diskPercent = Double(disk.usedBytes) / Double(disk.totalBytes) * 100
            diskUsedText = "已用 " + format(disk.usedBytes)
            diskFreeText = format(disk.totalBytes - disk.usedBytes)
            previousDisk = disk
        }

        let now = Date()
        let counters = SystemMetrics.networkBytes()
        if let previous = previousNetwork, let previousTime = previousNetworkTime {
            let seconds = max(0.5, now.timeIntervalSince(previousTime))
            downRate = Double(counters.received &- previous.received) / seconds
            upRate = Double(counters.sent &- previous.sent) / seconds
        }
        previousNetwork = counters
        previousNetworkTime = now
        netHistory = shift(netHistory, appending: downRate)

        load = SystemMetrics.loadAverage()
        battery = SystemMetrics.battery()
        processes = SystemMetrics.topProcesses()
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
