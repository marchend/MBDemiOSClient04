import SwiftUI

/// Dark navy rounded card shown at the top of the Home screen,
/// displaying the customer's identity and Okta authentication status.
///
/// Layout (top to bottom, all on navy background):
/// - "SIGNED IN" label (small caps, light grey)
/// - Circular avatar with the customer's initials
/// - Full display name (bold white)
/// - Auth row: shield SF Symbol + "Authenticated via Okta · Customer <id>"
///
/// Zero green/red: the palette is strictly navy / white / grey.
struct SignedInCardView: View {

    let displayName: String
    let customerId: String

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
                    Text(displayName)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                }
            }

            // Okta auth row
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .font(.body)

                Text("Authenticated via Okta \u{00B7} Customer \(customerId)")
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

#Preview {
    SignedInCardView(
        displayName: "Ada Lovelace",
        customerId: "user-123"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
