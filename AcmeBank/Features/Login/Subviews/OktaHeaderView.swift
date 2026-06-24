import SwiftUI

/// Horizontal strip at the top of the login screen showing the Okta domain
/// on the left and the Okta logo mark on the right.
struct OktaHeaderView: View {
    var body: some View {
        HStack {
            // Left: lock icon + domain text
            HStack(spacing: 4) {
                Image(systemName: "lock")
                    .font(.caption)
                Text("acmebank.okta.com")
                    .font(.caption)
            }

            Spacer()

            // Right: Okta circle mark + brand name
            HStack(spacing: 4) {
                Image(systemName: "circle.circle")
                    .font(.caption)
                Text("okta")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .foregroundStyle(Color(.secondaryLabel))
    }
}

#Preview {
    OktaHeaderView()
}
