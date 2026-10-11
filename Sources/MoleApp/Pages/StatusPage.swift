import SwiftUI

struct StatusPage: View {
    @ObservedObject var store: StatusStore
    @Environment(\.scenePhase) private var scenePhase

    private let columns = [
        GridItem(.adaptive(minimum: 230), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.hostName).font(.system(size: 15, weight: .semibold))
                    Text("\(store.chip) · \(store.memoryGB) GB 内存 · \(store.osVersion)")
                        .font(.system(size: 12)).foregroundStyle(Theme.dim2)
                }
                Spacer()
                Label(scenePhase == .active ? "前台采样" : "采样已暂停", systemImage: scenePhase == .active ? "waveform" : "pause.circle")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2).fixedSize()
            }
            LazyVGrid(columns: columns, spacing: 12) {
                healthCard
                cpuCard
                memCard
                diskCard
                gpuCard
                netCard
                loadCard
                batteryCard
            }
            processTable
        }
        .onAppear { if store.allowsLiveOperations { store.start() } }
        .onDisappear { if store.allowsLiveOperations { store.stop() } }
        .onChange(of: scenePhase) { _, phase in
            guard store.allowsLiveOperations else { return }
            if phase == .active { store.start() } else { store.stop() }
        }
    }

    private var healthCard: some View {
        StatCard(title: "运行概况", extra: "占用估算") {
            Text(store.hasCPUReading ? store.healthText : "采样中…").font(.system(size: 25, weight: .semibold))
            Text("基于 CPU、内存与磁盘占用\n不代表硬件健康")
                .font(.system(size: 12)).foregroundStyle(Theme.dim2).fixedSize(horizontal: false, vertical: true)
            Text("已运行 \(store.uptimeText) · 自 \(store.bootDateText)")
                .font(.system(size: 12)).foregroundStyle(Theme.dim2)
        }
    }

    private var cpuCard: some View {
        StatCard(title: "CPU", extra: store.temperature.map { String(format: "%.0f °C", $0) } ?? "温度不可用") {
            metricValue(store.hasCPUReading ? "\(Int(store.cpu)) %" : "—")
            if store.hasCPUReading {
                SparkView(values: store.cpuHistory, domain: 0...100)
                    .accessibilityLabel("CPU 历史利用率，固定范围 0 到 100%")
            } else {
                chartPlaceholder("等待利用率采样")
            }
            Text("\(store.coreCount) 核 · 每 1.5 秒更新")
                .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            Text("历史利用率 · 0–100% 固定刻度")
                .font(.system(size: 11.5)).foregroundStyle(Theme.dim2)
        }
    }

    private var gpuCard: some View {
        StatCard(title: "GPU", extra: "利用率") {
            metricValue(store.gpu.map { "\(Int($0)) %" } ?? "—")
            if store.gpu != nil {
                SparkView(values: store.gpuHistory, domain: 0...100)
                    .accessibilityLabel("GPU 历史利用率，固定范围 0 到 100%")
            } else {
                chartPlaceholder("暂无利用率读数")
            }
            Text(store.gpu == nil ? "当前未读取到 GPU 利用率" : "每 6 秒更新 · 0–100% 固定刻度")
                .font(.system(size: 12)).foregroundStyle(Theme.dim2)
        }
    }

    private var memCard: some View {
        StatCard(title: "内存", extra: "占用估算") {
            metricValue(store.memUsedText == "—" ? "—" : "\(Int(store.memPercent)) %")
            if store.memUsedText != "—" {
                BarView(value: store.memPercent)
                Text("已用 \(store.memUsedText)").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                Text(store.swapText).font(.system(size: 12)).foregroundStyle(Theme.dim2)
            } else {
                Text("当前未读取到内存数据").font(.system(size: 12)).foregroundStyle(Theme.dim2)
            }
        }
    }

    private var batteryCard: some View {
        StatCard(title: "电池", extra: store.battery.map { $0.onAC ? "接通电源" : "电池供电" } ?? "未检测到") {
            if let battery = store.battery {
                metricValue("\(battery.percent) %")
                BarView(value: Double(battery.percent))
                Text(battery.charging ? "充电中" : (battery.onAC ? "电源供电 · 未充电" : "电池供电"))
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
                Text("电量与供电状态 · 每 6 秒更新")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            } else {
                metricValue("—")
                Text("未读取到内置电池").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                Text("台式 Mac 或电池不可读")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            }
        }
    }

    private var diskCard: some View {
        StatCard(title: "磁盘可用", extra: "根卷 /") {
            metricValue(store.diskFreeText)
            if store.diskFreeText != "—" {
                BarView(value: store.diskPercent, warm: store.diskPercent >= 85)
                Text("\(store.diskUsedText) · \(Int(store.diskPercent))% 已用")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            } else {
                Text("当前未读取到磁盘数据").font(.system(size: 12)).foregroundStyle(Theme.dim2)
            }
        }
    }

    private var netCard: some View {
        StatCard(title: "网络下载", extra: "全部非回环接口") {
            metricValue(store.formatRate(store.downRate))
            SparkView(values: store.netHistory)
                .accessibilityLabel("下载速率历史，按当前历史峰值自动缩放")
            Text("上传 \(store.formatRate(store.upRate))")
                .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            Text("下载历史 · 自动刻度")
                .font(.system(size: 11.5)).foregroundStyle(Theme.dim2)
        }
    }

    private var loadCard: some View {
        StatCard(title: "平均负载", extra: "1 分钟") {
            metricValue(store.load.first.map { String(format: "%.2f", $0) } ?? "—")
            Text(String(format: "5 分钟 %.2f · 15 分钟 %.2f", store.load.count > 1 ? store.load[1] : 0, store.load.count > 2 ? store.load[2] : 0))
                .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            Text("\(store.coreCount) 核 · 负载并非 CPU 利用率")
                .font(.system(size: 11.5)).foregroundStyle(Theme.dim2)
            if let fan = store.fanRPM {
                Text(String(format: "风扇 %.0f RPM", fan))
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            } else {
                Text("风扇转速不可用")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            }
        }
    }

    private func metricValue(_ text: String) -> some View {
        Text(text).font(.system(size: 28, weight: .semibold)).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.8)
    }

    private func chartPlaceholder(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Theme.dim2)
            .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
    }

    private var processTable: some View {
        let maxMemory = max(store.processes.map(\.memBytes).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("内存占用较高的进程").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("前 \(store.processes.count) 项 · 每 6 秒更新")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            }.padding(.bottom, 4)
            HStack(spacing: 14) {
                Text("进程名称")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("内存").frame(width: 220, alignment: .leading)
                Text("CPU %").frame(width: 70, alignment: .trailing)
                Text("PID").frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.dim2)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            ForEach(store.processes) { proc in
                RowBox {
                    HStack(spacing: 14) {
                        Text(proc.name)
                            .font(.system(size: 13.5))
                            .lineLimit(1).truncationMode(.middle).help(proc.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 10) {
                            Text(AppsStore.formatBytes(proc.memBytes))
                                .font(Theme.mono)
                                .foregroundStyle(Theme.dim2)
                                .frame(width: 74, alignment: .leading)
                            BarView(value: Double(proc.memBytes) / Double(maxMemory) * 100, mini: true)
                                .help("相对于本列表内存占用最高的进程")
                                .accessibilityHidden(true)
                        }
                        .frame(width: 220, alignment: .leading)
                        Text(String(format: "%.1f", proc.cpu))
                            .font(Theme.mono).foregroundStyle(Theme.dim2)
                            .frame(width: 70, alignment: .trailing)
                        Text("\(proc.id)")
                            .font(Theme.mono).foregroundStyle(Theme.dim2)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
            if store.processes.isEmpty {
                Text("暂无进程读数，等待下一次采样。")
                    .font(.system(size: 13)).foregroundStyle(Theme.dim2).padding(14)
            }
            Text("内存条按本列表的最大值比较；单个进程的 CPU 占用可超过 100%。")
                .font(.system(size: 12)).foregroundStyle(Theme.dim2).padding(.top, 6)
        }
        .padding(.top, 18)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

struct StatCard<Content: View>: View {
    let title: String
    let extra: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).fontWeight(.medium).foregroundStyle(Theme.star)
                Spacer()
                Text(extra).font(.system(size: 11.5)).foregroundStyle(Theme.dim2).multilineTextAlignment(.trailing)
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.dim2)
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(minHeight: 184, alignment: .top)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
    }
}
