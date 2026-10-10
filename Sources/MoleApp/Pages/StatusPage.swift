import SwiftUI

struct StatusPage: View {
    @State private var metrics = Metrics()

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    struct Metrics {
        var cpu: Double = 12
        var gpu: Double = 11
        var mem: Double = 70
        var net: Double = 166
        var fan: Int = 0
    }

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
                fanCard
            }
            processTable
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                metrics.cpu = jitter(metrics.cpu, 6, 4, 68)
                metrics.gpu = jitter(metrics.gpu, 5, 2, 60)
                metrics.mem = jitter(metrics.mem, 2, 55, 88)
                metrics.net = jitter(metrics.net, 90, 3, 900)
                metrics.fan = metrics.cpu > 55 ? 1450 : 0
            }
        }
    }

    private func jitter(_ value: Double, _ spread: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        let next = value + (Double.random(in: 0...1) - 0.5) * spread
        return (min(maxValue, max(minValue, next)) * 10).rounded() / 10
    }

    private var healthCard: some View {
        StatCard(title: "✳ 健康度", extra: "M4 Pro · 32GB · macOS 26") {
            Text("100 很好").font(.system(size: 24))
            Text("各项指标正常").font(.system(size: 12)).foregroundStyle(Theme.dim2)
            Text("已运行 13 小时 · 自 9 月 27 日")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var cpuCard: some View {
        StatCard(title: "▤ CPU", extra: "46°C") {
            Text("\(Int(metrics.cpu)) %").font(.system(size: 24))
            SparkView()
            Text("低负载 · 负载 2.9 / 18 核")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var gpuCard: some View {
        StatCard(title: "▤ GPU", extra: "44°C") {
            Text("\(Int(metrics.gpu)) %").font(.system(size: 24))
            SparkView(tone: Color(hex: 0xC4A0E0))
            Text("低负载 · 20 GPU 核")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var memCard: some View {
        StatCard(title: "▤ 内存", extra: "压力 29%") {
            Text("\(Int(metrics.mem)) %").font(.system(size: 24))
            BarView(value: metrics.mem)
            Text(String(format: "%.2f GB · 交换空间 4.3 MB", metrics.mem * 0.48))
                .font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var batteryCard: some View {
        StatCard(title: "▮ 电池", extra: "健康 100%") {
            Text("80 %").font(.system(size: 24))
            Text("电源供电 · ×60W").font(.system(size: 12)).foregroundStyle(Theme.dim2)
            Text("52 次循环").font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var diskCard: some View {
        StatCard(title: "◔ 磁盘", extra: "995 GB") {
            Text("292 GB").font(.system(size: 24))
            BarView(value: 71, warm: true)
            Text("已用 703 GB · 71%").font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var netCard: some View {
        StatCard(title: "▷ 网络", extra: "Wi-Fi") {
            Text("\(Int(metrics.net)) KB/s").font(.system(size: 24))
            SparkView(tone: Color(hex: 0x8FB6D6))
            Text("↑ 91 KB/s · Wi-Fi").font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private var fanCard: some View {
        StatCard(title: "❋ 风扇", extra: "负载 \(metrics.fan > 0 ? "42%" : "0%")") {
            Text("\(metrics.fan) RPM").font(.system(size: 24))
            HStack(spacing: 0) {
                segment("自动", on: true)
                segment("增强", on: false)
                segment("极冷", on: false)
            }
            .overlay(Capsule().strokeBorder(Color(hex: 0xEFE8D8, opacity: 0.14)))
            .clipShape(Capsule())
            Text("由 macOS 调节").font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }

    private func segment(_ title: String, on: Bool) -> some View {
        Text(title)
            .font(.system(size: 11.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(on ? Color(hex: 0xEFE8D8, opacity: 0.14) : .clear)
            .foregroundStyle(on ? Theme.star : Theme.dim2)
    }

    private var processTable: some View {
        VStack(spacing: 1) {
            HStack(spacing: 14) {
                Text("名称（150）").frame(maxWidth: .infinity, alignment: .leading)
                Text("内存").frame(width: 220, alignment: .leading)
                Text("% CPU").frame(width: 70, alignment: .trailing)
                Text("PID").frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.dim3)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            ForEach(MockData.processes) { proc in
                RowBox {
                    HStack(spacing: 14) {
                        Text(proc.name)
                            .font(.system(size: 13.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 10) {
                            Text(proc.mem).font(Theme.mono).foregroundStyle(Theme.dim2)
                            BarView(value: proc.memPct, mini: true)
                                .overlay(Capsule().fill(.white.opacity(0.68)).frame(width: 60 * proc.memPct / 100), alignment: .leading)
                        }
                        .frame(width: 220, alignment: .leading)
                        Text(String(format: "%.1f", proc.cpu))
                            .font(Theme.mono).foregroundStyle(Theme.dim2)
                            .frame(width: 70, alignment: .trailing)
                        Text("\(proc.pid)")
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
        .frame(height: 138, alignment: .top)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
    }
}
