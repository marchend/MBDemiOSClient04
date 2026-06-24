import XCTest
import SwiftUI
import UIKit
@testable import AcmeBank

/// Unit coverage for `LandingView`.
///
/// We don't take SwiftUI snapshots (the existing test suite explicitly
/// avoids PNG-on-disk comparisons \u2014 see `LoginViewTests`). Instead we
/// embed the view in a `UIHostingController`, walk the rendered
/// `UIView` tree, and find the two accessibility identifiers the
/// XCUITest and screen-reader contract depend on.
///
/// The accessibility identifiers (`landing.welcome`, `landing.email`)
/// are the stable contract. If the visible copy is later restyled
/// these tests still pass as long as the identifiers remain attached
/// to text that contains the injected display name and email.
final class LandingViewTests: XCTestCase {

    private static func makeSession(
        displayName: String = "Ada Lovelace",
        email: String = "ada@acmebank.com"
    ) -> UserSession {
        UserSession(
            userId: "user-123",
            displayName: displayName,
            email: email,
            accessToken: "access-token",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName: "TestDevice"
        )
    }

    // MARK: - Hostable / non-throwing init

    func test_landingView_initializesWithoutThrowing() {
        let session = Self.makeSession()
        XCTAssertNoThrow(
            { _ = LandingView(session: session) }(),
            "LandingView should initialise without throwing"
        )
    }

    func test_landingView_hostsInUIHostingController() {
        let session = Self.makeSession()
        let view = LandingView(session: session)
        let hc = UIHostingController(rootView: AnyView(view))

        hc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        hc.view.setNeedsLayout()
        hc.view.layoutIfNeeded()

        XCTAssertFalse(hc.view.frame.isEmpty)
    }

    // MARK: - Accessibility identifier \u2192 rendered text contract

    func test_landingView_rendersInjectedDisplayName_underWelcomeIdentifier() {
        let session = Self.makeSession(displayName: "Grace Hopper")
        let hc = UIHostingController(rootView: LandingView(session: session))
        hc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        hc.view.layoutIfNeeded()

        let welcomeText = Self.findText(in: hc.view, identifier: "landing.welcome")
        XCTAssertNotNil(welcomeText, "No view found with accessibility identifier landing.welcome")
        XCTAssertEqual(welcomeText, "Welcome, Grace Hopper",
                       "landing.welcome must render \"Welcome, <displayName>\" exactly")
    }

    func test_landingView_rendersInjectedEmail_underEmailIdentifier() {
        let session = Self.makeSession(email: "grace@acmebank.com")
        let hc = UIHostingController(rootView: LandingView(session: session))
        hc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        hc.view.layoutIfNeeded()

        let emailText = Self.findText(in: hc.view, identifier: "landing.email")
        XCTAssertNotNil(emailText, "No view found with accessibility identifier landing.email")
        XCTAssertEqual(emailText, "grace@acmebank.com",
                       "landing.email must render the injected email exactly")
    }

    // MARK: - Helpers

    /// Walk the rendered UIView tree looking for a view whose
    /// `accessibilityIdentifier` matches `identifier`. Returns the
    /// effective rendered text \u2014 either `accessibilityLabel` (which
    /// SwiftUI populates from `Text` content) or the view's own
    /// `description` as a fallback.
    private static func findText(in root: UIView, identifier: String) -> String? {
        if root.accessibilityIdentifier == identifier {
            return root.accessibilityLabel
        }
        for sub in root.subviews {
            if let found = findText(in: sub, identifier: identifier) {
                return found
            }
        }
        return nil
    }
}
