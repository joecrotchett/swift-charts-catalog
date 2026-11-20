import XCTest

/// A tool, not a test: it opens one catalog screen and prints the accessibility elements iOS exposes
/// for it, so what VoiceOver would read can be checked without a device. It asserts nothing and is
/// not part of the gate. Run it with `scripts/ax-dump.sh <screen id>`.
/// A switch below the fold is scrolled to once before it is tapped.
final class AccessibilityDump: XCTestCase {
    /// Many screens in one run: TEST_RUNNER_SCREEN_IDS is a list of ids separated by ",". Each is launched
    /// in turn and printed between its own AXDUMP-BEGIN and AXDUMP-END. Run it with `scripts/ax-dump-batch.sh`.
    @MainActor
    func testDumpScreens() throws {
        let ids = (ProcessInfo.processInfo.environment["SCREEN_IDS"] ?? "").split(separator: ",").map(String.init)
        try XCTSkipIf(ids.isEmpty, "Set TEST_RUNNER_SCREEN_IDS to a list of screen ids.")
        let readsAudioGraph = ProcessInfo.processInfo.environment["AX_AUDIO_GRAPH"] == "1"
        for screenID in ids {
            let app = XCUIApplication()
            app.launchArguments = ["-screen", screenID]
            if readsAudioGraph { app.launchArguments.append("-dumpChartDescriptors") }
            app.launch()
            guard app.wait(for: .runningForeground, timeout: 20) else {
                print("AXDUMP-NOTE \(screenID) did not launch"); continue
            }
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
            sleep(2)
            print("AXDUMP-BEGIN \(screenID)")
            print(app.debugDescription)
            print("AXDUMP-END")
            if readsAudioGraph {
                for _ in 0 ..< 3 {
                    _ = app.debugDescription; sleep(2)
                }
            }
            app.terminate()
        }
    }

    @MainActor
    func testDumpScreen() throws {
        // xcodebuild passes TEST_RUNNER_SCREEN_ID to the runner as SCREEN_ID.
        let screenID = try XCTUnwrap(
            ProcessInfo.processInfo.environment["SCREEN_ID"], "Set TEST_RUNNER_SCREEN_ID to a catalog screen id."
        )
        let app = XCUIApplication()
        app.launchArguments = ["-screen", screenID]
        // TEST_RUNNER_AX_AUDIO_GRAPH=1: the app also writes the chart descriptors it finds while this
        // client keeps its accessibility tree alive (see ChartDescriptorDump).
        let readsAudioGraph = ProcessInfo.processInfo.environment["AX_AUDIO_GRAPH"] == "1"
        if readsAudioGraph { app.launchArguments.append("-dumpChartDescriptors") }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        // Let the chart draw and its elements settle.
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
        sleep(2)

        // Optionally operate controls first, to read a state other than the one the screen opens in:
        // TEST_RUNNER_AX_TAP is a list of accessibility labels separated by "|", tapped in order.
        for label in (ProcessInfo.processInfo.environment["AX_TAP"] ?? "").split(separator: "|").map(String.init) {
            let toggle = app.switches[label].firstMatch
            let button = app.buttons[label].firstMatch
            if toggle.waitForExistence(timeout: 3) {
                if !toggle.isHittable { app.swipeUp(); sleep(1) }
                // The switch itself sits at the row's trailing edge.
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            } else if button.waitForExistence(timeout: 3) {
                button.tap()
            } else {
                print("AXDUMP-NOTE no control labelled \(label)")
            }
            sleep(1)
        }
        if ProcessInfo.processInfo.environment["AX_TAP"] != nil { sleep(2) }

        print("AXDUMP-BEGIN \(screenID)")
        print(app.debugDescription)
        print("AXDUMP-END")
        if readsAudioGraph {
            // Keep querying, so the tree stays built while the app writes its descriptors.
            for _ in 0 ..< 4 {
                _ = app.debugDescription; sleep(2)
            }
        }
    }
}
