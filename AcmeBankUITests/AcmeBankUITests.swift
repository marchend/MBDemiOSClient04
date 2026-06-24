import XCTest

/// Bootstrap UI smoke test — proves the UI-test target compiles, links,
/// and can launch the app. Critical-flow UI tests (login, transfer,
/// sign-out) are deferred to their respective feature stories.
final class AcmeBankUITests: XCTestCase {
    func test_appLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
