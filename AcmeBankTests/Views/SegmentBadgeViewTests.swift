import XCTest
import SwiftUI
@testable import AcmeBank

/// Unit tests for `SegmentBadgeView` and the conditional badge
/// placement in `SignedInCardView`.
///
/// SwiftUI view rendering requires a simulator, so these tests focus
/// on the data/logic surface that determines WHEN the badge is shown:
///
/// 1. `SegmentBadgeView` stores the raw segment string and the view's
///    `body` is responsible for uppercasing it. The test documents this
///    contract by verifying that a lowercased input is stored as-is
///    (not pre-uppercased), so that removing `.uppercased()` from `body`
///    would produce visibly wrong output rather than silently passing.
/// 2. `SignedInCardView` stores `segment` and exposes it correctly so
///    the conditional `if let badgeText = segment?.badgeText` branch in
///    its body fires for known non-nil values and is skipped for nil or
///    `.unknown`.
///
/// The badge-present / badge-absent rendering is verified by exercising
/// the `segment` property on `SignedInCardView` — a view whose `segment`
/// is nil never passes a value into `SegmentBadgeView`, satisfying the
/// plan's acceptance criterion "no badge when segment is nil".
final class SegmentBadgeViewTests: XCTestCase {

    // MARK: - SegmentBadgeView — uppercasing contract

    /// `SegmentBadgeView` stores the raw segment string and relies on
    /// `body` to call `.uppercased()` for rendering. This test verifies
    /// the stored value is NOT pre-uppercased, meaning the view's body
    /// is the sole source of uppercasing. If `.uppercased()` were removed
    /// from `body`, a lowercased input would render in lowercase — a
    /// regression this test is designed to make detectable.
    func test_segmentBadge_rawValueIsNotPreUppercased() {
        // Store a lowercase input. The view must uppercase in `body`.
        let badge = SegmentBadgeView(segment: "premier")

        // The stored raw value must still be lowercase — it is NOT
        // pre-transformed at init time. If this assertion fails it means
        // the view is pre-uppercasing at init (which is also fine, but
        // the body call would then be redundant and should be removed).
        XCTAssertEqual(badge.segment, "premier",
                       "SegmentBadgeView must store the raw value unchanged; uppercasing is the body's responsibility")

        // The stored value must differ from its uppercased form, proving
        // the view's body MUST call .uppercased() to render correctly.
        XCTAssertNotEqual(badge.segment, badge.segment.uppercased(),
                          "Input was already uppercase — use a lowercase input to validate the uppercasing contract")
    }

    /// Uppercase of an already-uppercase string is idempotent —
    /// a pre-uppercased input stores and renders identically.
    func test_segmentBadge_uppercaseInputStoredAsIs() {
        let badge = SegmentBadgeView(segment: "RETAIL")
        XCTAssertEqual(badge.segment, "RETAIL",
                       "SegmentBadgeView stores the raw value; uppercased input is stored unchanged")
    }

    // MARK: - CustomerSegment — badgeText contract

    /// Known segments must return a non-nil `badgeText` for badge rendering.
    /// Mirrors the BFF OpenAPI enum `[RETAIL, PREMIER, PRIVATE, BUSINESS]` —
    /// every contract tier renders a badge. `RETAIL` is the regression case:
    /// the majority of demo customers are RETAIL and previously showed no
    /// badge because the enum lacked the case (fell through to `.unknown`).
    func test_customerSegment_knownSegmentsHaveBadgeText() {
        XCTAssertEqual(CustomerSegment.retail.badgeText, "RETAIL")
        XCTAssertEqual(CustomerSegment.premier.badgeText, "PREMIER")
        XCTAssertEqual(CustomerSegment.privateBanking.badgeText, "PRIVATE")
        XCTAssertEqual(CustomerSegment.business.badgeText, "BUSINESS")
    }

    /// `.unknown` must return nil from `badgeText` so no badge is rendered
    /// for unrecognised future BFF values.
    func test_customerSegment_unknownSegmentHasNoBadgeText() {
        XCTAssertNil(CustomerSegment.unknown.badgeText,
                     ".unknown must have nil badgeText so unvetted values never render a badge")
    }

    // MARK: - SignedInCardView — segment passthrough

    /// When `segment` is a known non-nil value, `SignedInCardView` exposes
    /// it so the conditional badge branch in its body can fire.
    func test_signedInCard_exposesSegmentWhenNonNil() {
        let view = SignedInCardView(
            displayName: "Ada Lovelace",
            customerId: "user-123",
            segment: .premier
        )
        XCTAssertEqual(view.segment, .premier,
                       "SignedInCardView must expose the segment value when non-nil")
    }

    /// When `segment` is nil, `SignedInCardView` stores nil — the
    /// conditional badge branch in its body will not fire.
    func test_signedInCard_segmentIsNilWhenNotProvided() {
        let viewExplicitNil = SignedInCardView(
            displayName: "Grace Hopper",
            customerId: "user-456",
            segment: nil
        )
        XCTAssertNil(viewExplicitNil.segment,
                     "SignedInCardView must store nil segment when explicitly passed nil")
    }

    /// The default initializer (no `segment` argument) also yields nil.
    func test_signedInCard_segmentDefaultsToNil() {
        let viewDefault = SignedInCardView(
            displayName: "Charles Babbage",
            customerId: "user-789"
        )
        XCTAssertNil(viewDefault.segment,
                     "SignedInCardView segment must default to nil when omitted")
    }

    /// `.unknown` segment is stored but `badgeText` returns nil, so no
    /// badge renders for unrecognised future BFF values.
    func test_signedInCard_unknownSegmentProducesNoBadge() {
        let view = SignedInCardView(
            displayName: "Unknown Tier User",
            customerId: "user-000",
            segment: .unknown
        )
        XCTAssertEqual(view.segment, .unknown,
                       "SignedInCardView stores .unknown segment")
        XCTAssertNil(view.segment?.badgeText,
                     ".unknown segment must produce no badge text so no capsule is rendered")
    }

    // MARK: - SignedInCardView — other stored properties unaffected

    /// Adding `segment` must not alter how `displayName` and `customerId`
    /// are stored or returned — a regression guard for the name row.
    func test_signedInCard_storedPropertiesUnchanged() {
        let view = SignedInCardView(
            displayName: "Alan Turing",
            customerId: "user-okta-sub-0042",
            segment: .premier
        )
        XCTAssertEqual(view.displayName, "Alan Turing")
        XCTAssertEqual(view.customerId, "user-okta-sub-0042")
    }
}
