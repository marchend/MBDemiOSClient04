import SwiftUI

/// Full-width "Sign in" button styled in Acme Navy.
struct SignInButtonView: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text("Sign in")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.acmeNavy)
                .cornerRadius(8)
                .opacity(isEnabled ? 1.0 : 0.4)
        }
        .disabled(!isEnabled)
        .accessibilityIdentifier("signInButton")
    }
}

#Preview {
    VStack(spacing: 16) {
        SignInButtonView(isEnabled: false, action: {})
        SignInButtonView(isEnabled: true, action: {})
    }
    .padding()
}
