import Darwin
import XCTest
@testable import MoleApp

final class CommandIntegrationTests: XCTestCase {
    func testTimeoutTerminatesProcessGroupIncludingTermIgnoringChild() async throws {
        let result = await CommandRunner.run("/bin/sh", ["-c", "trap '' TERM; /bin/sleep 30 & printf '%s' \"$!\"; while :; do :; done"], timeout: 0.2)
        XCTAssertEqual(result.code, 124)
        try await assertChildStopped(result.output)
    }

    func testCancellationTerminatesProcessGroup() async throws {
        let started = expectation(description: "child PID emitted")
        let task = Task {
            await CommandRunner.run("/bin/sh", ["-c", "trap '' TERM; /bin/sleep 30 & printf '%s' \"$!\"; while :; do :; done"], timeout: 10,
                                    onProgress: { line in if Int32(line) != nil { started.fulfill() } })
        }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.code, 130)
        try await assertChildStopped(result.output)
    }

    func testTimeoutCleansChildWhenParentExitsBeforeGracePeriod() async throws {
        let result = await CommandRunner.run("/bin/sh", ["-c", "(trap '' TERM; exec /bin/sleep 30) & printf '%s' \"$!\"; wait"], timeout: 0.2)
        XCTAssertEqual(result.code, 124)
        try await assertChildStopped(result.output)
    }

    private func assertChildStopped(_ text: String) async throws {
        let pid = try XCTUnwrap(Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertGreaterThan(pid, 1)
        guard pid > 1 else { return }
        if kill(pid, 0) == -1 && errno == ESRCH { return }
        let status = await CommandRunner.run("/bin/ps", ["-p", String(pid), "-o", "stat="], timeout: 2)
        // 被 init 接管、尚未回收的僵尸已经不能执行任何工作。
        let stopped = status.code == 0 && status.output.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Z")
            || (kill(pid, 0) == -1 && errno == ESRCH)
        if !stopped { kill(pid, SIGKILL) } // 只清理本测试生成的 sleep。
        XCTAssertTrue(stopped, "timeout/cancellation left a running child")
    }

    func testContinuousOutputCannotStarveTimeout() async {
        let start = ProcessInfo.processInfo.systemUptime
        let result = await CommandRunner.run("/bin/sh", ["-c", "while :; do printf 'abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz\n'; done"], timeout: 0.15)
        XCTAssertEqual(result.code, 124)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
    }

    func testOutputRemainsBoundedAndKeepsFinalError() async {
        let result = await CommandRunner.run("/bin/sh", ["-c", "printf 'START'; /bin/dd if=/dev/zero bs=65536 count=64 2>/dev/null; printf 'FINAL ERROR'; exit 7"], timeout: 5)
        XCTAssertEqual(result.code, 7)
        XCTAssertTrue(result.truncated)
        XCTAssertTrue(result.output.hasPrefix("START"))
        XCTAssertTrue(result.output.hasSuffix("FINAL ERROR"))
        XCTAssertLessThan(result.output.utf8.count, CommandRunner.OutputBuffer.limit + 100)
        XCTAssertTrue(result.failureMessage.contains("FINAL ERROR"))
    }

    func testOutputBufferNeverRetainsMoreThanLimit() {
        var buffer = CommandRunner.OutputBuffer()
        let chunk = Data(repeating: 65, count: 65_536)
        for _ in 0..<100 {
            buffer.append(chunk)
            XCTAssertLessThanOrEqual(buffer.storedBytes, CommandRunner.OutputBuffer.limit)
        }
        XCTAssertTrue(buffer.truncated)
        var exact = CommandRunner.OutputBuffer()
        exact.append(Data(repeating: 66, count: CommandRunner.OutputBuffer.limit))
        XCTAssertFalse(exact.truncated)
        XCTAssertEqual(exact.text.utf8.count, CommandRunner.OutputBuffer.limit)
    }

    func testArgumentsAreLiteralAndStdinIsClosed() async {
        let literal = "; $(echo injected) `echo injected` quote\" newline\n"
        let echo = await CommandRunner.run("/usr/bin/printf", ["%s", literal], timeout: 2)
        XCTAssertEqual(echo.code, 0)
        XCTAssertEqual(echo.output, literal)
        let cat = await CommandRunner.run("/bin/cat", [], timeout: 2)
        XCTAssertEqual(cat.code, 0)
        XCTAssertTrue(cat.output.isEmpty)
    }

    func testEnvironmentAndLaunchFailure() async {
        let result = await CommandRunner.run("/usr/bin/printenv", ["QILI_COMMAND_TEST"], timeout: 2,
                                             environment: ["QILI_COMMAND_TEST": "literal value"])
        XCTAssertEqual(result.output, "literal value\n")
        let missing = await CommandRunner.run("/does-not-exist-qili", [], timeout: 1)
        XCTAssertEqual(missing.code, -1)
        XCTAssertFalse(missing.error.isEmpty)
        let invalid = await CommandRunner.run("/bin/echo", ["a\0b"], timeout: 1)
        XCTAssertEqual(invalid.code, -1)
        let invalidTimeout = await CommandRunner.run("/bin/echo", [], timeout: .nan)
        XCTAssertEqual(invalidTimeout.code, -1)
        let signalled = await CommandRunner.run("/bin/sh", ["-c", "kill -TERM $$"], timeout: 2)
        XCTAssertEqual(signalled.code, 143)
    }

    func testProgressRemovesTerminalFormattingAndStaysBounded() {
        let line = CommandRunner.progressLine(Data("earlier\n\u{001b}[32mDownloading\u{001b}[0m\r\u{001b}[31mFinished\u{001b}[0m".utf8))
        XCTAssertEqual(line, "Finished")
        let long = CommandRunner.progressLine(Data(String(repeating: "a", count: 1000).utf8))
        XCTAssertEqual(long?.count, 240)
    }

    func testBrewFailureAndMalformedJSONAreNotSuccessfulEmptyChecks() {
        for result in [CommandRunner.Result(code: 124, output: "", error: "timeout"),
                       CommandRunner.Result(code: 1, output: "", error: "network failed"),
                       CommandRunner.Result(code: 0, output: "{}", error: ""),
                       CommandRunner.Result(code: 0, output: "not json", error: "")] {
            let report = UpdateStore.parseBrew(result)
            XCTAssertEqual(report.checkedSources, 0)
            XCTAssertFalse(report.warnings.isEmpty)
        }
        let empty = UpdateStore.parseBrew(.init(code: 0, output: "{\"formulae\":[],\"casks\":[]}", error: ""))
        XCTAssertEqual(empty.checkedSources, 1)
        XCTAssertTrue(empty.warnings.isEmpty)
    }

    func testBrewParsesFormulaAndCaskAndRejectsTruncatedData() {
        let json = """
        {"formulae":[{"name":"wget","installed_versions":["1.0"],"current_version":"2.0"}],
         "casks":[{"name":"app-token","installed_versions":["3.0"],"current_version":"4.0"}]}
        """
        let result = CommandRunner.Result(code: 0, output: json, error: "")
        let report = UpdateStore.parseBrew(result)
        XCTAssertEqual(report.updates.count, 2)
        guard case let .brew(token, isCask) = report.updates.last?.action else { return XCTFail("missing cask action") }
        XCTAssertEqual(token, "app-token")
        XCTAssertTrue(isCask)
        XCTAssertEqual(report.updates.last?.from, "3.0")
        var truncated = result
        truncated.truncated = true
        XCTAssertFalse(UpdateStore.parseBrew(truncated).warnings.isEmpty)
    }

    private actor Counter {
        var calls = 0
        func failedCheck() -> UpdateCheckReport {
            calls += 1
            return UpdateCheckReport(warnings: ["Homebrew：网络失败"])
        }
    }

    @MainActor
    func testFailedCheckIsShownAndCanRetryWithoutWaitingForCache() async {
        let counter = Counter()
        let store = UpdateStore(brewChecker: { await counter.failedCheck() })
        await store.check(apps: [])
        XCTAssertTrue(store.emptyCheckMessage.contains("失败"))
        XCTAssertFalse(store.checking)
        await store.check(apps: [])
        let calls = await counter.calls
        XCTAssertEqual(calls, 2)
    }

    @MainActor
    func testStopCheckDoesNotMarkItSuccessfulOrCacheCancellation() async throws {
        let store = UpdateStore(brewChecker: {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            return UpdateCheckReport()
        })
        let task = Task { await store.check(apps: []) }
        for _ in 0..<50 {
            if store.checking { break }
            await Task.yield()
        }
        store.stopChecking()
        await task.value
        XCTAssertTrue(store.checkWasCancelled)
        XCTAssertNil(store.lastChecked)
        XCTAssertFalse(store.checking)
        XCTAssertTrue(store.emptyCheckMessage.contains("停止"))
    }

    func testSparkleBuildAndDisplayVersionsAreNeverMixed() throws {
        let xml = """
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
        <sparkle:version>1248</sparkle:version><sparkle:shortVersionString>1.5.1</sparkle:shortVersionString>
        </item></channel></rss>
        """
        let item = try XCTUnwrap(AppcastParser.items(in: Data(xml.utf8)).first)
        XCTAssertEqual(item.build, "1248")
        XCTAssertEqual(item.displayVersion, "1.5.1")
        XCTAssertFalse(item.isNewer(thanBuild: "1248", displayVersion: "1.5.1"))
        XCTAssertFalse(item.isNewer(thanBuild: nil, displayVersion: "1.5.1"))
        XCTAssertTrue(item.isNewer(thanBuild: "1247", displayVersion: "1.5.1"))
    }

    func testSparkleItemsKeepTheirOwnCompatibilityAndLegacyAttributes() throws {
        let xml = """
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
        <item><enclosure sparkle:version="100" sparkle:shortVersionString="1.0"/></item>
        <item><sparkle:version>101</sparkle:version><sparkle:shortVersionString>1.1</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>99.0.0</sparkle:minimumSystemVersion></item>
        <item><sparkle:version>102</sparkle:version><sparkle:channel>beta</sparkle:channel></item>
        </channel></rss>
        """
        let items = try AppcastParser.items(in: Data(xml.utf8))
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].displayVersion, "1.0")
        XCTAssertTrue(items[0].isCompatible(with: "14.0.0"))
        XCTAssertFalse(items[1].isCompatible(with: "14.0.0"))
        XCTAssertFalse(items[2].isCompatible(with: "14.0.0"))
        XCTAssertFalse(items[2].isNewer(thanBuild: nil, displayVersion: "1.0"))
    }

    func testMalformedAppcastFailsAndUnrelatedVersionFieldsAreIgnored() throws {
        XCTAssertThrowsError(try AppcastParser.items(in: Data("<rss><channel><item>".utf8)))
        XCTAssertThrowsError(try AppcastParser.items(in: Data("<html/>".utf8)))
        let xml = "<rss><channel><item><version>999</version><minimumSystemVersion>100</minimumSystemVersion></item></channel></rss>"
        XCTAssertTrue(try AppcastParser.items(in: Data(xml.utf8)).isEmpty)
    }

    func testAppcastNamespaceAliasesAndTopLevelVersionTakePriority() throws {
        let xml = """
        <rss xmlns:s="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
        <s:version>200</s:version><s:shortVersionString>2.0</s:shortVersionString>
        <enclosure s:version="100" s:shortVersionString="1.0"/>
        </item><item><enclosure s:version="300" s:shortVersionString="3.0"/></item></channel></rss>
        """
        let items = try AppcastParser.items(in: Data(xml.utf8))
        XCTAssertEqual(items.map(\.build), ["200", "300"])
        XCTAssertEqual(items.map(\.displayVersion), ["2.0", "3.0"])
    }

    func testLaunchctlLoadedAndRunningAreSeparateAndOverridesKeepFalse() {
        let states = LoginItemsStore.parseLoaded("PID\tStatus\tLabel\n-\t0\tcom.test.idle\n42\t0\tcom.test.running\n-\t-9\tcom.test.failed\n")
        XCTAssertEqual(states.count, 3)
        XCTAssertNil(states["com.test.idle"]?.processID)
        XCTAssertEqual(states["com.test.running"]?.processID, 42)
        XCTAssertEqual(states["com.test.failed"]?.lastExit, -9)
        let disabled = LoginItemsStore.parseDisabled("{\n\"com.test.idle\" => true\n\"com.test.running\" => false\n}")
        XCTAssertEqual(disabled["com.test.idle"], true)
        XCTAssertEqual(disabled["com.test.running"], false)
        var entry = LoginEntry(id: "fixture", label: "fixture", program: nil, scope: .user)
        XCTAssertEqual(entry.stateText, "状态未知")
        entry.stateKnown = true
        entry.loaded = true
        XCTAssertEqual(entry.stateText, "已启用 · 等待触发")
        entry.processID = 42
        XCTAssertEqual(entry.stateText, "已启用 · 运行中")
        entry.disabled = true
        XCTAssertEqual(entry.stateText, "已停用 · 仍在运行")
    }

    func testMaintenanceHonorsExitCodeAndDoesNotDiagnoseTimeoutAsDiskDamage() {
        let partial = OptimizeStore.interpret(.init(code: 124, output: "Indexing enabled", error: "timeout"), taskID: "spotlight")
        XCTAssertEqual(partial.status, .failed)
        let disk = OptimizeStore.interpret(.init(code: 124, output: "started", error: "timeout"), taskID: "disk")
        XCTAssertTrue(disk.message.contains("超时"))
        XCTAssertFalse(disk.message.contains("校验未通过"))
        XCTAssertEqual(OptimizeStore.interpret(.init(code: 1, output: "", error: "error"), taskID: "quicklook").status, .failed)
    }
}
