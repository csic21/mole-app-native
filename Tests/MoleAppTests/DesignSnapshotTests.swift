#if DEBUG
import AppKit
import SwiftUI
import XCTest
@testable import MoleApp

/// The normal test run checks fixture safety. PNG capture is explicitly opt-in.
/// Nothing here creates ContentView, MoleApp, polling stores, or a live scan.
final class DesignSnapshotTests: XCTestCase {
    @MainActor
    func testNewStoreWaitsForAnExplicitScan() {
        let store = CleanStore()
        XCTAssertEqual(store.phase, .ready)
        XCTAssertFalse(store.hasScanned)
        XCTAssertFalse(store.scanning)
        XCTAssertTrue(store.categories.isEmpty)
        XCTAssertTrue(store.allowsLiveOperations)
    }

    @MainActor
    func testSnapshotActionsCannotStartLiveWork() async {
        for scenario in DesignScenario.allCases {
            let store = scenario.makeStore()
            let phase = store.phase
            let paths = store.categories.flatMap(\.children).map(\.id)
            let roots = store.categories.map(\.root)
            let selected = store.selected
            let scanning = store.scanning
            let stopped = store.stopped
            let hasScanned = store.hasScanned
            let moved = store.result?.moved
            let failed = store.result?.failed

            XCTAssertFalse(store.allowsLiveOperations, scenario.rawValue)
            XCTAssertTrue(roots.allSatisfy { $0.path.hasPrefix("/QiliPreview/") })
            XCTAssertTrue(paths.allSatisfy { $0.hasPrefix("/QiliPreview/") })
            store.scan()
            store.scan(showProgress: false)
            store.stop()
            await store.trash()

            XCTAssertEqual(store.phase, phase, scenario.rawValue)
            XCTAssertEqual(store.categories.map(\.root), roots, scenario.rawValue)
            XCTAssertEqual(store.categories.flatMap(\.children).map(\.id), paths, scenario.rawValue)
            XCTAssertEqual(store.selected, selected, scenario.rawValue)
            XCTAssertEqual(store.scanning, scanning, scenario.rawValue)
            XCTAssertEqual(store.stopped, stopped, scenario.rawValue)
            XCTAssertEqual(store.hasScanned, hasScanned, scenario.rawValue)
            XCTAssertEqual(store.result?.moved, moved, scenario.rawValue)
            XCTAssertEqual(store.result?.failed, failed, scenario.rawValue)
        }
    }

    @MainActor
    func testEmptyAndInaccessibleFixturesAreDistinct() {
        let empty = DesignScenario.empty.makeStore()
        let inaccessible = DesignScenario.inaccessible.makeStore()
        XCTAssertTrue(empty.categories.allSatisfy { $0.measured && !$0.partial && $0.children.isEmpty })
        XCTAssertTrue(inaccessible.categories.allSatisfy { $0.measured && $0.partial && $0.children.isEmpty })
        XCTAssertEqual(empty.categories.reduce(0) { $0 + $1.sizeBytes }, 0)
        XCTAssertEqual(inaccessible.categories.reduce(0) { $0 + $1.sizeBytes }, 0)
    }

    @MainActor
    func testCleanupFixturesCoverSuccessPartialAndFailure() throws {
        let success = try XCTUnwrap(DesignScenario.completed.makeStore().result)
        let partial = try XCTUnwrap(DesignScenario.partial.makeStore().result)
        let failure = try XCTUnwrap(DesignScenario.failed.makeStore().result)
        XCTAssertGreaterThan(success.moved, 0)
        XCTAssertEqual(success.failed, 0)
        XCTAssertTrue(success.failures.isEmpty)
        XCTAssertGreaterThan(partial.moved, 0)
        XCTAssertGreaterThan(partial.failed, 0)
        XCTAssertEqual(partial.failures.count, partial.failed)
        XCTAssertEqual(failure.moved, 0)
        XCTAssertEqual(failure.movedBytes, 0)
        XCTAssertGreaterThan(failure.failed, 0)
        XCTAssertEqual(failure.failures.count, failure.failed)
    }

    func testCleanupOutcomeUsesCountsInsteadOfClaimingFreedSpace() {
        let cases: [(TrashResult?, CleanOutcomePresentation.Kind, String, String)] = [
            (TrashResult(moved: 4, failed: 0, movedBytes: 4096), .completed,
             "已移到废纸篓", "checkmark.circle"),
            (TrashResult(moved: 2, failed: 1, movedBytes: 2048), .partial,
             "部分项目未能移动", "exclamationmark.circle"),
            (TrashResult(moved: 0, failed: 3, movedBytes: 0), .failed,
             "未能移动所选项目", "xmark.circle"),
            (TrashResult(moved: 0, failed: 0, movedBytes: 0), .unchanged,
             "未移动任何项目", "info.circle"),
            (nil, .unchanged, "未移动任何项目", "info.circle"),
            // Zero-byte files can be moved successfully. Size must not imply failure.
            (TrashResult(moved: 1, failed: 0, movedBytes: 0), .completed,
             "已移到废纸篓", "checkmark.circle"),
            (TrashResult(moved: 1, failed: 1, movedBytes: 0), .partial,
             "部分项目未能移动", "exclamationmark.circle"),
        ]
        for (result, kind, title, symbol) in cases {
            let presentation = CleanOutcomePresentation(result: result)
            XCTAssertEqual(presentation.kind, kind)
            XCTAssertEqual(presentation.title, title)
            XCTAssertEqual(presentation.symbol, symbol)
            XCTAssertFalse(presentation.title.contains("已释放"))
        }
    }

    @MainActor
    func testCaptureNativeDesignSnapshots() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["QILI_CAPTURE_SNAPSHOTS"] == "1" else {
            throw XCTSkip("Opt in with scripts/capture_design_snapshots.sh to write native PNGs.")
        }
        let outputPath = try XCTUnwrap(environment["QILI_SNAPSHOT_DIRECTORY"],
                                       "An explicit QILI_SNAPSHOT_DIRECTORY is required.")
        XCTAssertTrue(outputPath.hasPrefix("/"), "The output directory must be absolute.")
        guard outputPath.hasPrefix("/") else { return }
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        // This starts AppKit inside XCTest, never the @main application entry point.
        let app = NSApplication.shared
        guard !NSScreen.screens.isEmpty else {
            XCTFail("Native capture needs a graphical macOS login session with a screen.")
            return
        }
        let oldAppearance = app.appearance
        app.appearance = NSAppearance(named: .darkAqua)
        defer { app.appearance = oldAppearance }

        let sizes = [NSSize(width: 1060, height: 680), NSSize(width: 1220, height: 820)]
        let plans: [(scenario: DesignScenario, size: NSSize, increasedContrast: Bool)] =
            sizes.flatMap { size in DesignScenario.allCases.map { ($0, size, false) } }
            + [(.selection, sizes[0], true), (.partial, sizes[0], true)]
        var captures: [[String: Any]] = []
        for plan in plans {
            let scenario = plan.scenario
            let size = plan.size
            let store = scenario.makeStore()
            let scene = WorkspaceShell(tab: .constant(.clean), scrollKey: scenario.rawValue) {
                CleanPage(store: store)
            } footer: {
                if store.phase == .list { CleanSelectionBar(store: store) }
            }
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .environment(\.colorScheme, .dark)
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }

            let variant = plan.increasedContrast ? "-increased-contrast" : ""
            let name = "clean-\(scenario.rawValue)-\(Int(size.width))x\(Int(size.height))\(variant).png"
            let destination = output.appendingPathComponent(name)
            try capture(scene, size: size, increasedContrast: plan.increasedContrast, to: destination)
            XCTAssertFalse(store.allowsLiveOperations)
            captures.append([
                "file": name,
                "scenario": scenario.rawValue,
                "width": Int(size.width),
                "height": Int(size.height),
                "scale": 1,
                "contrast": plan.increasedContrast ? "increased" : "standard",
                "appearance": plan.increasedContrast ? "accessibilityHighContrastDarkAqua" : "darkAqua",
            ])
        }

        let manifest: [String: Any] = [
            "runID": environment["QILI_SNAPSHOT_RUN_ID"] ?? UUID().uuidString,
            "renderer": "NSHostingView + NSWindow native frame + NSView.cacheDisplay",
            "locale": "zh_CN",
            "data": "Synthetic /QiliPreview fixtures; live operations disabled",
            "system": ProcessInfo.processInfo.operatingSystemVersionString,
            "note": "Native fonts and AppKit rendering vary with the macOS release. These are review captures, not cross-OS pixel baselines.",
            "captures": captures,
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("manifest.json"), options: .atomic)
        XCTAssertEqual(captures.count, DesignScenario.allCases.count * sizes.count + 2)
    }

    @MainActor
    private func capture<V: View>(_ root: V, size: NSSize, increasedContrast: Bool, to destination: URL) throws {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "栖理"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: increasedContrast ? .accessibilityHighContrastDarkAqua : .darkAqua)
        window.backgroundColor = NSColor(Theme.canvas)
        window.isMovableByWindowBackground = true
        window.animationBehavior = .none
        window.contentView = NSHostingView(rootView: root)
        // Set the complete frame, so exported PNG dimensions include native chrome.
        window.setFrame(NSRect(origin: NSPoint(x: 100, y: 100), size: size), display: true)
        window.orderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }

        // Let SwiftUI/AppKit finish their scheduled layout, without starting app stores.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
        let frame = try XCTUnwrap(window.contentView?.superview)
        frame.layoutSubtreeIfNeeded()
        pauseIndeterminateIndicators(in: frame)
        frame.displayIfNeeded()
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            let button = try XCTUnwrap(window.standardWindowButton(kind))
            XCTAssertFalse(button.isHidden, "Native window controls must remain visible.")
        }
        XCTAssertEqual(Int(frame.bounds.width), Int(size.width))
        XCTAssertEqual(Int(frame.bounds.height), Int(size.height))

        // Explicit 1x output is independent of the connected display's Retina scale.
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        bitmap.size = size
        frame.cacheDisplay(in: frame.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: destination, options: .atomic)
        let decoded = try XCTUnwrap(NSBitmapImageRep(data: png))
        XCTAssertEqual(decoded.pixelsWide, Int(size.width))
        XCTAssertEqual(decoded.pixelsHigh, Int(size.height))
        XCTAssertGreaterThan(png.count, 10_000, "Unexpectedly empty native capture: \(destination.lastPathComponent)")
    }

    @MainActor
    private func pauseIndeterminateIndicators(in view: NSView) {
        if let indicator = view as? NSProgressIndicator, indicator.isIndeterminate {
            // Keep the real native control visible, only stop its animation clock.
            indicator.isDisplayedWhenStopped = true
            indicator.usesThreadedAnimation = false
            indicator.stopAnimation(nil)
        }
        view.subviews.forEach { pauseIndeterminateIndicators(in: $0) }
    }
}

private enum DesignScenario: String, CaseIterable {
    case initial, scanning, results, selection, empty, inaccessible, trashing, completed, partial, failed

    @MainActor
    func makeStore() -> CleanStore {
        var categories = Self.categories()
        let selected = Set(categories[0].children.map(\.id))
        switch self {
        case .initial:
            return CleanStore(snapshot: .init(phase: .ready, hasScanned: false))
        case .scanning:
            for index in 2..<categories.count {
                categories[index].measured = false
                categories[index].children = []
                categories[index].sizeBytes = 0
            }
            return CleanStore(snapshot: .init(phase: .scanning, categories: categories,
                scanning: true, measuredCount: 2, currentCategory: "Xcode 构建缓存"))
        case .results:
            return CleanStore(snapshot: .init(phase: .result, categories: categories,
                                              measuredCount: categories.count))
        case .selection:
            return CleanStore(snapshot: .init(phase: .list, categories: categories,
                measuredCount: categories.count, selected: selected, expanded: ["user-caches"]))
        case .empty, .inaccessible:
            for index in categories.indices {
                categories[index].children = []
                categories[index].sizeBytes = 0
                categories[index].partial = self == .inaccessible
            }
            return CleanStore(snapshot: .init(phase: .result, categories: categories,
                                              measuredCount: categories.count))
        case .trashing:
            return CleanStore(snapshot: .init(phase: .trashing, categories: categories,
                measuredCount: categories.count, selected: selected))
        case .completed:
            return CleanStore(snapshot: .init(phase: .done, categories: [], result:
                TrashResult(moved: 8, failed: 0, movedBytes: 4_194_304_000)))
        case .partial:
            return CleanStore(snapshot: .init(phase: .done, categories: [], result:
                TrashResult(moved: 6, failed: 2, movedBytes: 3_145_728_000, failures: [
                    "com.example.canvas：路径已变化或不可访问",
                    "Build.log：没有权限移动此项目",
                ])))
        case .failed:
            return CleanStore(snapshot: .init(phase: .done, categories: [], result:
                TrashResult(moved: 0, failed: 2, movedBytes: 0, failures: [
                    "com.example.canvas：路径已变化或不可访问",
                    "Build.log：没有权限移动此项目",
                ])))
        }
    }

    private static func categories() -> [CleanCategory] {
        [
            category("user-caches", "用户缓存", "应用缓存，删除后会自动重建", [
                ("com.example.canvas", 1_677_721_600),
                ("com.example.browser", 838_860_800),
                ("com.example.notes", 314_572_800),
            ]),
            category("user-logs", "用户日志", "诊断与运行日志", [
                ("Build.log", 104_857_600),
                ("Session.log", 52_428_800),
            ]),
            category("xcode-derived", "Xcode 构建缓存", "DerivedData，重新构建即可恢复", [
                ("SampleWorkspace", 1_258_291_200),
            ]),
            category("xcode-device", "Xcode 设备支持", "设备符号，重新连接设备会恢复", [
                ("Example Device Symbols", 629_145_600),
            ]),
            category("npm", "npm 缓存", "_cacache，重新下载即可", [
                ("_cacache", 419_430_400),
            ]),
        ]
    }

    private static func category(_ id: String, _ title: String, _ note: String,
                                 _ entries: [(String, Int64)]) -> CleanCategory {
        let root = URL(fileURLWithPath: "/QiliPreview/\(id)", isDirectory: true)
        let items = entries.map { entry in
            CleanItem(id: root.appendingPathComponent(entry.0).path, name: entry.0, sizeBytes: entry.1)
        }
        return CleanCategory(id: id, title: title, note: note, root: root, mode: .children,
            measured: true, sizeBytes: items.reduce(0) { $0 + $1.sizeBytes }, children: items)
    }
}
#endif
