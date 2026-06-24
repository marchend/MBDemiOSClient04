import SwiftUI

/// Full-width "Sign in" button styled in Acme Navy.
///
/// While a sign-in is in flight (`isSigningIn == true`) the label is
/// replaced with a white `ProgressView` spinner and the button is
/// disabled, so the user gets feedback that the request is running and
/// cannot double-tap into a second concurrent auth call. The button is
/// also disabled (and dimmed) when `isEnabled == false`.
struct SignInButtonView: View {
    let isEnabled: Bool
    var isSigningIn: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // Keep the "Sign in" label out of the layout while the
                // spinner shows (hidden, not removed) so the button
                // height stays stable across states.
                Text("Sign in")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(isSigningIn ? 0 : 1)

                if isSigningIn {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.acmeNavy)
            .cornerRadius(8)
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .disabled(!isEnabled || isSigningIn)
        .accessibilityIdentifier("signInButton")
        .accessibilityLabel(isSigningIn ? "Signing in" : "Sign in")
    }
}

#Preview {
    VStack(spacing: 16) {
        SignInButtonView(isEnabled: false, action: {})
        SignInButtonView(isEnabled: true, action: {})
        SignInButtonView(isEnabled: true, isSigningIn: true, action: {})
    }
    .padding()
}
