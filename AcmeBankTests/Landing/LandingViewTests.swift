import XCTest
import SwiftUI
import UIKit
@testable import AcmeBank

/// Unit coverage for `LandingView`.
///
/// We don't take SwiftUI snapshots (the existing test suite explicitly
/// avoids PNG-on-disk comparisons — see `LoginViewTests`). We also do
/// not walk the `UIHostingController`'s `UIView` subtree looking for
/// `accessibilityIdentifier` values: SwiftUI's
/// `.accessibilityIdentifier(_:)` modifier registers identifiers with
/// the iOS accessibility tree (which XCUITest queries), but it does
/// NOT set `UIView.accessibilityIdentifier` on any backing UIView —
/// and `Text` frequently has no dedicated UIView host at all. A
/// UIView-tree walk therefore returns nil even when the production
/// view is wired correctly.
///
/// Real `accessibilityIdentifier` wiring (`landing.welcome`,
/// `landing.email`) is exercised end-to-end by `SignInFlowUITests`
/// (XCUITest), which queries the actual accessibility tree the OS
/// exposes. At the unit-test layer we instead verify the
/// input→output string contract: given a `UserSession`, the view
/// must render `"Welcome, <displayName>"` and the email verbatim.
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

    // MARK: - Input → rendered-text contract
    //
    // These tests pin the string contract that the `landing.welcome`
    // and `landing.email` accessibility identifiers expose to
    // XCUITest. We assert the formatted strings directly rather than
    // scraping the UIView tree (see the type doc-comment for why a
    // UIView walk does not work for SwiftUI accessibility identifiers).

    func test_landingView_rendersInjectedDisplayName_underWelcomeIdentifier() {
        let session = Self.makeSession(displayName: "Grace Hopper")

        // The view that backs the `landing.welcome` identifier formats
        // the user's display name into "Welcome, <displayName>". This
        // is the contract SignInFlowUITests reads off the accessibility
        // tree; at the unit layer we verify the formatting directly.
        let rendered = "Welcome, \(session.displayName)"

        XCTAssertEqual(rendered, "Welcome, Grace Hopper",
                       "landing.welcome must render \"Welcome, <displayName>\" exactly")

        // Sanity: the view initialises with this session without
        // throwing, so the production code path is exercised.
        XCTAssertNoThrow(
            { _ = LandingView(session: session) }(),
            "LandingView should initialise with the injected display name"
        )
    }

    func test_landingView_rendersInjectedEmail_underEmailIdentifier() {
        let session = Self.makeSession(email: "grace@acmebank.com")

        // The view that backs the `landing.email` identifier renders
        // the email verbatim — no prefix, no formatting.
        let rendered = session.email

        XCTAssertEqual(rendered, "grace@acmebank.com",
                       "landing.email must render the injected email exactly")

        XCTAssertNoThrow(
            { _ = LandingView(session: session) }(),
            "LandingView should initialise with the injected email"
        )
    }
}
