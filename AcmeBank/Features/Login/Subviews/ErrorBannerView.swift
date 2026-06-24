import SwiftUI

/// Inline error banner displayed below the password field when an error occurs.
struct ErrorBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color(.secondaryLabel))

            Text(message)
                .font(.footnote)
                .foregroundStyle(Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    ErrorBannerView(message: "Invalid username or password. Please try again.")
        .padding()
}
