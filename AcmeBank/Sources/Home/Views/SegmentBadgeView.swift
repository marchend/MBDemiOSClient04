import SwiftUI

/// A monochrome capsule badge that displays the customer's segment
/// tier (e.g. `"PREMIER"`, `"STANDARD"`).
///
/// Rendered with a semi-transparent white background so it sits
/// cleanly on the dark-navy `SignedInCardView` without introducing
/// any accent colour or interactive affordance.
///
/// - The segment string is always uppercased regardless of the value
///   received from the BFF.
/// - No tap action; this is a purely decorative informational label.
struct SegmentBadgeView: View {

    /// The customer segment label received from the BFF (e.g. `"PREMIER"`).
    let segment: String

    var body: some View {
        Text(segment.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Customer segment: \(segment.uppercased())")
    }
}

// MARK: - Preview

#Preview("Segment badge — PREMIER") {
    SegmentBadgeView(segment: "PREMIER")
        .padding()
        .background(Color.acmeBrandNavy)
}

#Preview("Segment badge — lowercase input") {
    SegmentBadgeView(segment: "standard")
        .padding()
        .background(Color.acmeBrandNavy)
}
