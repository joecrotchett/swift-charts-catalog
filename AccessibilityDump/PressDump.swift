import XCTest

/// A tool, not a test: it opens one catalog screen, makes one gesture on the chart, and prints the
/// accessibility elements iOS exposes afterwards, so a selection or scroll position can be read back
/// without a device. It asserts nothing and is not part of the gate.
/// Run it with `scripts/press-dump.sh <screen id> "<gesture>" [simulator] [controls to tap first]`.
///
/// The gesture is a verb and one or two points, each a fraction of the box the chart's own
/// elements cover (0,0 is its top-left corner, whatever the layout direction). For bars and lines
/// that box is the plot area; for points it is the points' extent. The chart's container element
/// is not used, as its frame can be wider than the screen and offset from the chart.
///   tap 0.5,0.5 · hold 0.5,0.5 · drag 0.2,0.5 0.8,0.5 · swipe 0.5,0.8 0.5,0.1
/// `hold` and `drag` keep the finger down for PRESS_HOLD seconds at the end (default 4) and print
/// PRESS-HOLDING while it is down, so the script can take screenshots of the selection as drawn.
/// `swipe` is a fast drag with no hold, as a reader flicking the page would make.
final class PressDump: XCTestCase {
    @MainActor
    func testPressScreen() throws {
        let env = ProcessInfo.processInfo.environment
        let screenID = try XCTUnwrap(env["SCREEN_ID"], "Set TEST_RUNNER_SCREEN_ID to a catalog screen id.")
        let gesture = try XCTUnwrap(env["PRESS_GESTURE"], "Set TEST_RUNNER_PRESS_GESTURE, such as \"tap 0.5,0.5\".")
        let hold = TimeInterval(env["PRESS_HOLD"] ?? "") ?? 4

        let app = XCUIApplication()
        app.launchArguments = ["-screen", screenID]
        // PRESS_RTL=1 runs the app right to left, as a right-to-left language would.
        if env["PRESS_RTL"] == "1" {
            app.launchArguments += ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"]
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
        sleep(2)

        for label in (env["AX_TAP"] ?? "").split(separator: "|").map(String.init) {
            let toggle = app.switches[label].firstMatch
            let button = app.buttons[label].firstMatch
            if toggle.waitForExistence(timeout: 3) {
                if !toggle.isHittable { app.swipeUp(); sleep(1); app.swipeDown(); sleep(1) }
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            } else if button.waitForExistence(timeout: 3) {
                button.tap()
            } else {
                print("PRESS-NOTE no control labelled \(label)")
            }
            sleep(1)
        }

        let chart = try XCTUnwrap(chartBox(in: app, identifier: env["PRESS_TARGET"] ?? "press-target"), "PRESS-NOTE no chart found on \(screenID)")
        print("PRESS-CHART-FRAME \(chart)")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let parts = gesture.split(separator: " ").map(String.init)
        let points = try parts.dropFirst().map { try point($0, in: chart, from: origin) }
        XCTAssertFalse(points.isEmpty, "PRESS-NOTE the gesture names no point")

        switch parts.first {
        case "tap":
            points[0].tap()
        case "hold":
            print("PRESS-HOLDING")
            points[0].press(forDuration: 0.6, thenDragTo: points[0], withVelocity: .slow, thenHoldForDuration: hold)
        case "drag":
            let end = try XCTUnwrap(points.dropFirst().first, "PRESS-NOTE a drag needs two points")
            print("PRESS-HOLDING")
            points[0].press(forDuration: 0.3, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: hold)
        case "scroll":
            // Slow enough for a scrolling chart to follow (60 points a second); faster drags left it still.
            let end = try XCTUnwrap(points.dropFirst().first, "PRESS-NOTE a scroll needs two points")
            print("PRESS-HOLDING")
            points[0].press(forDuration: 0.2, thenDragTo: end, withVelocity: 60, thenHoldForDuration: 0.3)
        case "swipe":
            let end = try XCTUnwrap(points.dropFirst().first, "PRESS-NOTE a swipe needs two points")
            points[0].press(forDuration: 0.01, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
        default:
            XCTFail("PRESS-NOTE unknown gesture \(gesture)")
        }
        print("PRESS-RELEASED")
        sleep(2)
        // The runner's output reaches the script late, so the shot after the finger lifts is taken here.
        if let out = env["PRESS_OUT"] {
            let shot = XCUIScreen.main.screenshot().pngRepresentation
            try shot.write(to: URL(fileURLWithPath: out).appendingPathComponent("released.png"))
        }

        print("AXDUMP-BEGIN \(screenID) after \(gesture)")
        print(app.debugDescription)
        print("AXDUMP-END")
    }

    /// The chart is the first container on the page holding two or more elements with a label and a
    /// value (Swift Charts' own elements, one per mark or per series); the box is their union.
    /// A chart with no elements of its own (a `Chart3D`) is found by the identifier `press-target`
    /// instead, and the box is its frame.
    @MainActor
    /// The chart to press: the element with `identifier` if there is one (a screen with several charts names
    /// each, and PRESS_TARGET picks one), otherwise the topmost box of labelled elements.
    private func chartBox(in app: XCUIApplication, identifier: String) -> CGRect? {
        let target = app.descendants(matching: .any)[identifier]
        if target.exists {
            // A named chart may sit below the fold (the dashboard on iPhone): scroll until all of it is in the
            // window, clear of the tab bar, with slow swipes started away from the charts' own gestures.
            let window = app.windows.firstMatch.frame
            var swipes = 0
            while target.frame.maxY > window.maxY - 120, swipes < 8 {
                app.scrollViews.firstMatch.swipeUp(velocity: .slow)
                swipes += 1
            }
            return target.frame
        }
        let candidates = app.scrollViews.firstMatch.descendants(matching: .other).allElementsBoundByIndex
        return candidates
            .map { element in
                element.children(matching: .other).allElementsBoundByIndex
                    .filter { !$0.label.isEmpty && ($0.value as? String).map { !$0.isEmpty } == true }
                    .map(\.frame)
            }
            .filter { $0.count >= 2 }
            .map { $0.dropFirst().reduce($0[0]) { $0.union($1) } }
            .min { $0.minY < $1.minY }
    }

    private func point(_ text: String, in box: CGRect, from origin: XCUICoordinate) throws -> XCUICoordinate {
        let numbers = text.split(separator: ",").compactMap { Double($0) }
        guard numbers.count == 2 else { throw PressError.badPoint(text) }
        return origin.withOffset(CGVector(dx: box.minX + numbers[0] * box.width, dy: box.minY + numbers[1] * box.height))
    }

    private enum PressError: Error { case badPoint(String) }
}
