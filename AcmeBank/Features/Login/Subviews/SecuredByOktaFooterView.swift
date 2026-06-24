import SwiftUI

/// Centred footer indicating this login is powered by Okta.
struct SecuredByOktaFooterView: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Secured by")
                .font(.caption)

            Image(systemName: "circle.circle")
                .font(.caption)

            Text("okta")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    SecuredByOktaFooterView()
        .padding()
}
