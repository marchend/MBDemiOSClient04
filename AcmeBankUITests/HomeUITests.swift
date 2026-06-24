import XCTest

/// End-to-end XCUITest: sign in to the app, verify the Home screen
/// appears, tap Log Out, and assert that the Login screen is shown.
///
/// **Heavily guarded.** This test is only meaningful when ALL of the
/// following are true on the CI runner:
///   1. The four `OKTA_*` build-time env vars are set (so the build's
///      Info.plist has real values, not sentinel placeholders).
///   2. `OKTA_TEST_USERNAME` / `OKTA_TEST_PASSWORD` are set (so we
///      have credentials to type into the form).
///
/// When any of those conditions is absent we `XCTSkipUnless` and the
/// test reports as skipped — NOT failed. CI with no Okta credentials
/// stays green and the app launches normally showing the login screen.
final class HomeUITests: XCTestCase {

    private static let buildEnvVars = [
        "OKTA_ISSUER",
        "OKTA_CLIENT_ID",
        "OKTA_REDIRECT_URI",
        "OKTA_SCOPES"
    ]

    private static let testCredentialEnvVars = [
        "OKTA_TEST_USERNAME",
        "OKTA_TEST_PASSWORD"
    ]

    private static func allEnvVarsPresent(_ names: [String]) -> Bool {
        let env = ProcessInfo.processInfo.environment
        return names.allSatisfy { (env[$0] ?? "").isEmpty == false }
    }

    private static func infoPlistKeysLookReal() -> Bool {
        let env = ProcessInfo.processInfo.environment
        for key in buildEnvVars {
            let raw = (env[key] ?? "").trimmingCharacters(in: .whitespaces)
            if raw.isEmpty { return false }
            if raw.hasPrefix("__") && raw.hasSuffix("_UNSET__") { return false }
        }
        return true
    }

    // MARK: - Test: Log Out flow

    /// Full end-to-end UI flow:
    ///   1. Sign in with test credentials.
    ///   2. Wait for the Home screen to appear (identified by the
    ///      "home.logOut" accessibility identifier on the Log Out
    ///      button).
    ///   3. Tap Log Out.
    ///   4. Assert that the Login screen is visible (Sign In button
    ///      accessible via "signInButton").
    func test_logOut_returnsToLoginScreen() throws {
        try XCTSkipUnless(
            Self.allEnvVarsPresent(Self.buildEnvVars),
            "Skipping live Okta sign-in flow: one or more OKTA_* build env vars are not set."
        )
        try XCTSkipUnless(
            Self.infoPlistKeysLookReal(),
            "Skipping live Okta sign-in flow: OKTA_* env vars look like __<KEY>_UNSET__ sentinels."
        )
        try XCTSkipUnless(
            Self.allEnvVarsPresent(Self.testCredentialEnvVars),
            "Skipping live Okta sign-in flow: OKTA_TEST_USERNAME / OKTA_TEST_PASSWORD not set."
        )

        let env = ProcessInfo.processInfo.environment
        // Force-unwraps are safe — the XCTSkipUnless above verified
        // both keys are present and non-empty.
        let username = env["OKTA_TEST_USERNAME"]!
        let password = env["OKTA_TEST_PASSWORD"]!

        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // --- Sign In ---

        let usernameField = app.textFields["Username"]
        XCTAssertTrue(
            usernameField.waitForExistence(timeout: 5),
            "Username field did not appear on launch"
        )
        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(
            passwordField.waitForExistence(timeout: 2),
            "Password field did not appear"
        )
        passwordField.tap()
        passwordField.typeText(password)

        let signInButton = app.buttons["signInButton"]
        XCTAssertTrue(
            signInButton.waitForExistence(timeout: 2),
            "Sign In button did not appear"
        )
        signInButton.tap()

        // --- Wait for Home screen ---

        let logOutButton = app.buttons["home.logOut"]
        XCTAssertTrue(
            logOutButton.waitForExistence(timeout: 30),
            "Home screen 'Log Out' button did not appear within 30 s of tapping Sign In"
        )

        // --- Tap Log Out ---

        logOutButton.tap()

        // --- Assert Login screen is presented ---

        // The Login screen re-appears with its Sign In button.
        XCTAssertTrue(
            signInButton.waitForExistence(timeout: 10),
            "Login screen (signInButton) did not appear after tapping Log Out"
        )
    }
}
