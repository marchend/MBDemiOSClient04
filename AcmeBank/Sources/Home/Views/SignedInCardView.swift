import SwiftUI

/// Dark navy rounded card shown at the top of the Home screen,
/// displaying the customer's identity and Okta authentication status.
///
/// Layout (top to bottom, all on navy background):
/// - "SIGNED IN" label (small caps, light grey)
/// - Circular avatar with the customer's initials
/// - Full display name (bold white) + optional segment badge
/// - Auth row: shield SF Symbol + "Authenticated via Okta · ···XXXX"
///
/// The `customerId` (Okta `sub` claim) is never rendered verbatim.
/// Only the last four characters are shown, preceded by `···`, to
/// avoid surfacing email prefixes, sequential integers, or other
/// PII-adjacent values that some IdP configurations embed in `sub`.
///
/// Zero green/red: the palette is strictly navy / white / grey.
/// The segment badge (if present) uses a semi-transparent white
/// background so no accent colour is introduced.
struct SignedInCardView: View {

    let displayName: String
    let customerId: String
    /// Optional customer segment label (e.g. `"PREMIER"`).
    /// When non-nil a `SegmentBadgeView` is rendered to the right of
    /// the display name. When nil the name row layout is unchanged.
    let segment: String?

    // MARK: - Init

    init(displayName: String, customerId: String, segment: String? = nil) {
        self.displayName = displayName
        self.customerId = customerId
        self.segment = segment
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // "SIGNED IN" label
            Text("SIGNED IN")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.6))
                .tracking(1.2)

            // Avatar + name row
            HStack(spacing: 14) {
                avatarView
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    // Name + optional segment badge on the same row
                    HStack(alignment: .center) {
                        Text(displayName)
                            .font(.headline)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                        if let seg = segment {
                            SegmentBadgeView(segment: seg)
                        }
                    }
                }
            }

            // Okta auth row — masked customer ID (last 4 chars only)
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .font(.body)

                Text("Authenticated via Okta \u{00B7} \(maskedCustomerId)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.acmeBrandNavy)
        )
    }

    // MARK: - Private

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined()
    }

    /// Returns a masked form of `customerId` that exposes only the last
    /// four characters, e.g. `"user-abc123"` → `"···3123"`.
    /// If the ID is four characters or shorter it is fully masked as
    /// `"···"` to avoid exposing the entire value.
    private var maskedCustomerId: String {
        guard customerId.count > 4 else { return "\u{00B7}\u{00B7}\u{00B7}" }
        let suffix = customerId.suffix(4)
        return "\u{00B7}\u{00B7}\u{00B7}\(suffix)"
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
            Text(initials)
                .font(.headline)
                .bold()
                .foregroundColor(.white)
        }
    }
}

// MARK: - Previews

#Preview("With PREMIER segment badge") {
    SignedInCardView(
        displayName: "Ada Lovelace",
        customerId: "user-123",
        segment: "PREMIER"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Without segment (nil)") {
    SignedInCardView(
        displayName: "Ada Lovelace",
        customerId: "user-123",
        segment: nil
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
