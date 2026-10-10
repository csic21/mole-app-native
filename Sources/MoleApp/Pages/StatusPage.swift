import SwiftUI

struct StatusPage: View {
    @StateObject private var store = StatusStore()

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: columns, spacing: 10) {
                healthCard
                cpuCard
                gpuCard
                memCard
                batteryCard
                diskCard
                netCard
                loadCard
            }
            processTable
        }
        .onAppear { store.start() }
        .onDisappear { store.stop() }
    }

    private var healthCard: some View {
        StatCard(title: "✳ 健康度", extra: "\(store.chip) · \(store.memoryGB)GB · \(store.osVersion)") {
            Text("\(store.healthScore) \(store.healthText)").font(.system(size: 24))
            Text("各项指标正常").font(.system(size: 12)).foregroundStyle(Theme.dim2)
            Text("已运行 \(store.uptimeText) · 自 \(store.bootDateText)")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var cpuCard: some View {
        StatCard(title: "▤ CPU", extra: "\(store.coreCount) 核") {
            Text("\(Int(store.cpu)) %").font(.system(size: 24))
            SparkView(values: store.cpuHistory)
            Text("实时采样 · 每 1.5 秒")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var gpuCard: some View {
        StatCard(title: "▤ GPU", extra: "—") {
            Text("—").font(.system(size: 24))
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(height: 26)
            Text("GPU 利用率需 IOKit 扩展,下一步接入")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var memCard: some View {
        StatCard(title: "▤ 内存", extra: "压力 \(Int(store.memPercent))%") {
            Text("\(Int(store.memPercent)) %").font(.system(size: 24))
            BarView(value: store.memPercent)
            Text(store.memUsedText).font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var batteryCard: some View {
        StatCard(title: "▮ 电池", extra: store.battery == nil ? "台式" : "接通电源") {
            if let battery = store.battery {
                Text("\(battery.percent) %").font(.system(size: 24))
                Text(battery.charging ? "电源供电 · 充电中" : "电池供电")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
                Text("循环次数需 SMC,下一步接入")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim3)
            } else {
                Text("—").font(.system(size: 24))
                Text("没有内置电池").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                Text("台式 Mac 或电池不可读")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim3)
            }
        }
    }

    private var diskCard: some View {
        StatCard(title: "◔ 磁盘", extra: "根卷") {
            Text(store.diskFreeText).font(.system(size: 24))
            BarView(value: store.diskPercent, warm: true)
            Text("\(store.diskUsedText) · \(Int(store.diskPercent))%")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var netCard: some View {
        StatCard(title: "▷ 网络", extra: "全部接口") {
            Text(store.formatRate(store.downRate)).font(.system(size: 24))
            SparkView(values: store.netHistory, tone: Color(hex: 0x8FB6D6))
            Text("↑ \(store.formatRate(store.upRate))")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var loadCard: some View {
        StatCard(title: "❋ 负载", extra: "\(store.coreCount) 核") {
            Text(String(format: "%.2f", store.load.first ?? 0)).font(.system(size: 24))
            Text(String(format: "5 分钟 %.2f · 15 分钟 %.2f", store.load.count > 1 ? store.load[1] : 0, store.load.count > 2 ? store.load[2] : 0))
                .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            Text("风扇转速需 SMC,下一步接入")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var processTable: some View {
        let maxMemory = max(store.processes.map(\.memBytes).max() ?? 1, 1)
        return VStack(spacing: 1) {
            HStack(spacing: 14) {
                Text("名称(真实进程 · 按内存 TOP \(store.processes.count))")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("内存").frame(width: 220, alignment: .leading)
                Text("% CPU").frame(width: 70, alignment: .trailing)
                Text("PID").frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.dim3)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            ForEach(store.processes) { proc in
                RowBox {
                    HStack(spacing: 14) {
                        Text(proc.name)
                            .font(.system(size: 13.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 10) {
                            Text(AppsStore.formatBytes(proc.memBytes))
                                .font(Theme.mono)
                                .foregroundStyle(Theme.dim2)
                                .frame(width: 74, alignment: .leading)
                            BarView(value: Double(proc.memBytes) / Double(maxMemory) * 100, mini: true)
                                .overlay(
                                    Capsule()
                                        .fill(.white.opacity(0.68))
                                        .frame(width: 60 * Double(proc.memBytes) / Double(maxMemory)),
                                    alignment: .leading
                                )
                        }
                        .frame(width: 220, alignment: .leading)
                        Text(String(format: "%.1f", proc.cpu))
                            .font(Theme.mono).foregroundStyle(Theme.dim2)
                            .frame(width: 70, alignment: .trailing)
                        Text("\(proc.id)")
                            .font(Theme.mono).foregroundStyle(Theme.dim3)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.top, 8)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(extra).font(Theme.monoSmall).foregroundStyle(Theme.dim3)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.dim2)
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(height: 148, alignment: .top)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
    }
}
