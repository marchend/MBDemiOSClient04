import SwiftUI

/// Post-sign-in Landing screen.
///
/// Bootstrap-spec content: a "Welcome, <displayName>" headline with
/// the user's email rendered directly below. Nothing else \u2014 a real
/// dashboard / accounts list lands in a later feature story. This view
/// is the FIRST visible proof that the Okta Direct-Auth flow round
/// tripped a real ID token whose claims survived JWT decode and were
/// projected into a `UserSession`.
///
/// Accessibility identifiers (`landing.welcome`, `landing.email`) are
/// the contract `SignInFlowUITests` and unit tests assert against. They
/// stay stable even if the visible copy is later restyled, so the
/// XCUITest doesn't have to chase font / layout changes.
struct LandingView: View {
    let session: UserSession

    var body: some View {
        VStack(spacing: 12) {
            // Em-dash-free, simple welcome line. We interpolate
            // `displayName` rather than the raw `name` claim so the
            // fallback chain in `UserSession` (name \u2192 email \u2192 sub)
            // applies if a partial-profile tenant returned a sparse
            // ID token.
            Text("Welcome, \(session.displayName)")
                .font(.title)
                .accessibilityIdentifier("landing.welcome")

            Text(session.email)
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("landing.email")
        }
        .padding()
    }
}

#Preview {
    LandingView(
        session: UserSession(
            userId: "user-123",
            displayName: "Ada Lovelace",
            email: "ada@acmebank.com",
            accessToken: "preview-access",
            authTimestamp: Date(),
            deviceName: "Preview"
        )
    )
}
