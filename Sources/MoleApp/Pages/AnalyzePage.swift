import SwiftUI

struct AnalyzePage: View {
    @State private var path: [MockData.TreeNode] = [MockData.root]

    private var node: MockData.TreeNode { path.last ?? MockData.root }
    private var children: [MockData.TreeNode] {
        (node.children).sorted { $0.sizeMB > $1.sizeMB }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            side
            VStack(alignment: .leading, spacing: 10) {
                mapHead
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(children) { child in
                        tile(child)
                    }
                }
                FootBar(note: path.count > 1 ? "第 \(path.count) 层 · 点面包屑返回" : "点方块进入下一层") {
                    PillButton(title: "返回上一层", disabled: path.count <= 1) {
                        if path.count > 1 { path.removeLast() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var side: some View {
        VStack(spacing: 6) {
            JupiterView()
                .padding(.top, 4)
                .padding(.bottom, 6)
            Text("\(children.count + 139) 项 · \(node.sizeText)")
                .font(.system(size: 13))
            Text("当前目录")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.dim3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            ForEach(children) { child in
                Button {
                    enter(child)
                } label: {
                    HStack(spacing: 8) {
                        Text(child.name)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(child.sizeText).font(Theme.mono).foregroundStyle(Theme.dim2)
                        Text("›").foregroundStyle(Theme.dim3)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 12)
            Text("右键可打开或移到废纸篓")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 248)
        .padding(.trailing, 12)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.line).frame(width: 1)
        }
    }

    private var mapHead: some View {
        HStack {
            HStack(spacing: 0) {
                ForEach(Array(path.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Text(" › ").foregroundStyle(Theme.dim3) }
                    Button(item.name) {
                        path = Array(path.prefix(index + 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.dim2)
                }
            }
            .font(.system(size: 12.5))
            Spacer()
            Text("文件 \(node.sizeText) · 已用 702 / 994 GB")
                .font(Theme.mono)
                .foregroundStyle(Theme.dim2)
        }
        .padding(.top, 2)
    }

    private func tile(_ child: MockData.TreeNode) -> some View {
        Button {
            enter(child)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("▸ \(child.name)").font(.system(size: 12.5, weight: .semibold))
                Text(child.sizeText)
                    .font(Theme.monoSmall)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .frame(height: 102)
            .background(child.tone, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white.opacity(0.9))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func enter(_ child: MockData.TreeNode) {
        guard !child.children.isEmpty else { return }
        path.append(child)
    }
}

struct JupiterView: View {
    var size: CGFloat = 74

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [Color(hex: 0xD9B184), Color(hex: 0xB98A5C), Color(hex: 0xE2C39A), Color(hex: 0xA97A4E)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            Circle().fill(
                RadialGradient(
                    colors: [.white.opacity(0.3), .clear],
                    center: UnitPoint(x: 0.32, y: 0.28),
                    startRadius: 2,
                    endRadius: size * 0.6
                )
            )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 6).blur(radius: 4))
    }
}
