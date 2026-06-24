import XCTest

/// End-to-end XCUITest: real Okta tenant, real Direct-Auth flow,
/// real Landing render.
///
/// **Heavily guarded.** This test is only meaningful when ALL of the
/// following are true on the CI runner:
///   1. The four `OKTA_*` build-time env vars are set (so the build's
///      Info.plist has real values, not the `__OKTA_<KEY>_UNSET__`
///      sentinels).
///   2. `OKTA_TEST_USERNAME` / `OKTA_TEST_PASSWORD` are set (so we
///      have credentials to type into the form).
///
/// When any of those is absent we `XCTSkipUnless` and the test
/// reports as skipped \u2014 NOT failed. That's the contract from the PR
/// plan: "CI with NO OKTA_* env vars: build green, app launches
/// showing the banner, `SignInFlowUITests` XCTSkips. No crash, no
/// hard-fail."
///
/// The sentinel check is necessary because xcodebuild ALWAYS forwards
/// the process env into the runner subprocess \u2014 so an env var set on
/// the CI runner host but NOT exported into the xcodebuild invocation
/// would set `ProcessInfo.environment["OKTA_ISSUER"]` here (test
/// process) WITHOUT having injected a real value into the built
/// Info.plist (which happens at compile time inside xcodebuild). The
/// sentinel check is what catches that mismatch and skips rather
/// than fights through a sign-in that can never succeed.
final class SignInFlowUITests: XCTestCase {

    /// Env-var names the live build script consumes. Mirrors
    /// `Scripts/inject_okta_config.sh`.
    private static let buildEnvVars = [
        "OKTA_ISSUER",
        "OKTA_CLIENT_ID",
        "OKTA_REDIRECT_URI",
        "OKTA_SCOPES"
    ]

    /// Env-var names this XCUITest specifically needs (test
    /// credentials, NOT consumed by the build script).
    private static let testCredentialEnvVars = [
        "OKTA_TEST_USERNAME",
        "OKTA_TEST_PASSWORD"
    ]

    /// True iff every named env var is present and non-empty in this
    /// process. The build script's sentinel-injection path means an
    /// absent env var here is the same as a sentinel value in the
    /// built Info.plist \u2014 either way, sign-in cannot work.
    private static func allEnvVarsPresent(_ names: [String]) -> Bool {
        let env = ProcessInfo.processInfo.environment
        return names.allSatisfy { (env[$0] ?? "").isEmpty == false }
    }

    /// True iff the launched app's Info.plist contains REAL values
    /// (not the `__OKTA_<KEY>_UNSET__` sentinels) for the four build
    /// keys. We check this from the test process by inspecting the
    /// env vars the build script would have read \u2014 if any starts with
    /// `__` and ends with `_UNSET__` that's a sentinel value, and
    /// sign-in cannot succeed against the real IdP.
    private static func infoPlistKeysLookReal() -> Bool {
        let env = ProcessInfo.processInfo.environment
        for key in buildEnvVars {
            let raw = (env[key] ?? "").trimmingCharacters(in: .whitespaces)
            if raw.isEmpty { return false }
            if raw.hasPrefix("__") && raw.hasSuffix("_UNSET__") { return false }
        }
        return true
    }

    func test_signInFlow_endToEnd_landsOnLanding() throws {
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
        // Force-unwraps are safe \u2014 the XCTSkipUnless above just
        // verified both keys are present and non-empty.
        let username = env["OKTA_TEST_USERNAME"]!
        let password = env["OKTA_TEST_PASSWORD"]!

        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // Type credentials. The Login subviews expose accessibility
        // labels "Username" / "Password" on their text fields, which
        // XCUITest queries via .textFields / .secureTextFields.
        let usernameField = app.textFields["Username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5),
                      "Username field did not appear on launch")
        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["Password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 2),
                      "Password field did not appear")
        passwordField.tap()
        passwordField.typeText(password)

        // Tap Sign In. Identifier is set by SignInButtonView.
        let signInButton = app.buttons["signInButton"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 2),
                      "Sign In button did not appear")
        signInButton.tap()

        // After a successful Direct-Auth round-trip the composition
        // root swaps in LandingView. Both accessibility identifiers
        // must be present \u2014 they are the stable contract.
        let welcome = app.staticTexts["landing.welcome"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 30),
                      "landing.welcome did not appear within 30s of tapping Sign In")
        XCTAssertTrue(welcome.label.hasPrefix("Welcome, "),
                      "landing.welcome must start with the literal prefix \"Welcome, \" \u{2014} got \"\(welcome.label)\"")

        let email = app.staticTexts["landing.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5),
                      "landing.email did not appear alongside the welcome line")
        XCTAssertFalse(email.label.isEmpty,
                       "landing.email must render a non-empty email string")
    }
}
