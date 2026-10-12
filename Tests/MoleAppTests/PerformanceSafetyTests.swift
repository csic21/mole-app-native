import XCTest
@testable import MoleApp

final class PerformanceSafetyTests: XCTestCase {
    private func fixture() throws -> URL {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    private func file(_ root: URL, _ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        var bytes = [UInt8]()
        bytes.reserveCapacity(32_768)
        for index in 0..<32_768 {
            let value: Int = (index * 13 + index / 256) % 251
            bytes.append(UInt8(value))
        }
        try Data(bytes).write(to: url)
        return url
    }

    func testFileMeasurementCountsRegularFilesAndSkipsSymlinks() throws {
        let root = try fixture()
        let regular = try file(root, "regular.log")
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let second = try file(nested, ".hidden")
        let outside = try fixture()
        _ = try file(outside, "must-not-count")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked"), withDestinationURL: outside)
        let measured = FileSizer.measure(root)
        XCTAssertGreaterThan(FileSizer.measure(regular).bytes, 0)
        XCTAssertEqual(measured.bytes, FileSizer.measure(regular).bytes + FileSizer.measure(second).bytes)
        XCTAssertFalse(measured.partial)
        XCTAssertEqual(FileSizer.measure(root.appendingPathComponent("linked")).bytes, 0)
    }

    func testSparseFileUsesAllocationInsteadOfLogicalSize() throws {
        let root = try fixture()
        let url = root.appendingPathComponent("sparse")
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seek(toOffset: 64 * 1024 * 1024)
        try handle.write(contentsOf: Data([42]))
        try handle.close()
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey])
        let result = FileSizer.measure(url)
        XCTAssertEqual(result.bytes, Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0))
        XCTAssertLessThan(result.bytes, Int64(values.fileSize ?? 0))
        XCTAssertFalse(result.partial)
    }

    func testMissingPathIsIncompleteInsteadOfEmpty() throws {
        let result = FileSizer.measure(try fixture().appendingPathComponent("missing"))
        XCTAssertTrue(result.partial)
        XCTAssertEqual(result.bytes, 0)
    }

    func testCancelledMeasurementDoesNotTraverse() async throws {
        let root = try fixture()
        _ = try file(root, "existing")
        let task = Task.detached {
            while !Task.isCancelled { await Task.yield() }
            return FileSizer.measure(root)
        }
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.bytes, 0)
        XCTAssertTrue(result.partial)
    }

    func testCleanScanIncludesLooseFilesAndRespectsExclusions() async throws {
        let root = try fixture()
        let log = try file(root, "loose.log")
        _ = try file(root, "com.apple.protected")
        _ = try file(root, ".hidden")
        _ = try file(root, "DiagnosticReports")
        let category = CleanCategory(id: "fixture", title: "fixture", note: "", root: root,
                                     mode: .children, skipPrefixes: ["com.apple."], skipNames: ["DiagnosticReports"])
        let result = await CleanStore.measure(category)
        XCTAssertEqual(result.children.map(\.id), [log.path])
        XCTAssertEqual(result.sizeBytes, FileSizer.measure(log).bytes)
        XCTAssertGreaterThan(result.sizeBytes, 0)
        XCTAssertTrue(result.measured)
    }

    func testCleanupValidationRejectsOutsideNestedAndReplacedParent() throws {
        let root = try fixture()
        let child = try file(root, "allowed")
        let category = CleanCategory(id: "fixture", title: "fixture", note: "", root: root, mode: .children)
        XCTAssertTrue(CleanStore.isValidCleanupTarget(child, category: category))
        XCTAssertFalse(CleanStore.isValidCleanupTarget(root, category: category))
        let outside = try fixture()
        XCTAssertFalse(CleanStore.isValidCleanupTarget(try file(outside, "outside"), category: category))
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        XCTAssertFalse(CleanStore.isValidCleanupTarget(try file(nested, "nested-file"), category: category))
        try FileManager.default.removeItem(at: root)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: outside)
        _ = try file(outside, "allowed")
        XCTAssertFalse(CleanStore.isValidCleanupTarget(child, category: category))
    }

    @MainActor
    func testSingleSelectionDoesNotSelectSiblings() {
        let store = CleanStore()
        let items = [CleanItem(id: "a", name: "a", sizeBytes: 100), CleanItem(id: "b", name: "b", sizeBytes: 200)]
        let category = CleanCategory(id: "category", title: "", note: "", root: URL(fileURLWithPath: "/fixture"), mode: .children, children: items)
        store.toggleItem("a")
        XCTAssertEqual(store.selected, ["a"])
        store.toggleCategory(category)
        XCTAssertEqual(store.selected, ["a", "b"])
        store.toggleItem("b")
        XCTAssertEqual(store.selected, ["a"])
        store.toggleCategory(category)
        store.toggleCategory(category)
        XCTAssertTrue(store.selected.isEmpty)
    }

    @MainActor
    func testAnalyzeNavigationUsesCacheAndRejectsStaleResults() async throws {
        let root = try fixture()
        let child = root.appendingPathComponent("child")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        _ = try file(child, "expected")
        let other = try fixture()
        _ = try file(other, "other")
        let store = AnalyzeStore()
        store.open(other)
        store.open(root)
        try await waitForScan(store)
        XCTAssertEqual(store.items.map(\.name), ["child"])
        store.enter(try XCTUnwrap(store.items.first))
        try await waitForScan(store)
        XCTAssertEqual(store.items.map(\.name), ["expected"])
        store.goUp()
        XCTAssertTrue(store.fromCache)
        XCTAssertFalse(store.sizing)
        XCTAssertEqual(store.items.map(\.name), ["child"])
        store.rescan()
        XCTAssertFalse(store.fromCache)
        try await waitForScan(store)
    }

    @MainActor
    private func waitForScan(_ store: AnalyzeStore) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while store.sizing && ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(store.sizing, "scan did not complete")
    }

    func testLargeStdoutAndStderrDoNotDeadlock() async {
        let result = await CommandRunner.run("/bin/sh", ["-c", "i=0; while [ $i -lt 6000 ]; do printf 'stdout line %s abcdefghijklmnopqrstuvwxyz\n' $i; printf 'stderr line %s abcdefghijklmnopqrstuvwxyz\n' $i >&2; i=$((i+1)); done"], timeout: 5)
        XCTAssertEqual(result.code, 0)
        XCTAssertTrue(result.output.contains("stdout line 5999"))
        XCTAssertTrue(result.error.contains("stderr line 5999"))
        XCTAssertTrue(result.combined.contains("stderr line 5999"))
    }

    func testTimeoutKillsTermIgnoringChildAndPreservesOutput() async {
        let start = ProcessInfo.processInfo.systemUptime
        let result = await CommandRunner.run("/bin/sh", ["-c", "trap '' TERM; printf 'before timeout'; while :; do :; done"], timeout: 0.15)
        XCTAssertEqual(result.code, 124)
        XCTAssertTrue(result.output.contains("before timeout"))
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
    }

    func testCommandCancellationIsPropagated() async throws {
        let start = ProcessInfo.processInfo.systemUptime
        let task = Task { await CommandRunner.run("/bin/sleep", ["10"], timeout: 20) }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.code, 130)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
    }

    func testNetworkCounterResetDoesNotBecomeHugeRate() {
        XCTAssertEqual(StatusStore.counterRate(current: 100, previous: 200, seconds: 1.5), 0)
        XCTAssertEqual(StatusStore.counterRate(current: 350, previous: 200, seconds: 1.5), 100)
        XCTAssertEqual(StatusStore.counterRate(current: 350, previous: 200, seconds: 0), 0)
    }

    func testZeroByteFormatting() {
        XCTAssertEqual(AppsStore.formatBytes(0), "0 B")
        XCTAssertEqual(AppsStore.formatBytes(512), "512 B")
    }
}
