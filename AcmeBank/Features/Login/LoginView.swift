import SwiftUI

/// The login screen.
///
/// Composed of:
/// - `OktaHeaderView` — domain strip at the top
/// - Scrollable body — hex logo, title, subtitle, fields, error banner, sign-in button
/// - `SecuredByOktaFooterView` — pinned at the bottom
struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top header strip
            OktaHeaderView()

            // Scrollable content area
            ScrollView {
                VStack(spacing: 24) {
                    // Logo + headings
                    VStack(spacing: 12) {
                        HexLogoView()

                        Text("Sign in")
                            .font(Font.titleLarge)
                            .foregroundStyle(Color(.label))

                        Text("Sign in to your Acme Bank account")
                            .font(Font.bodyRegular)
                            .foregroundStyle(Color.subtitleText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // Input fields
                    VStack(spacing: 16) {
                        UsernameFieldView(username: $viewModel.username)

                        PasswordFieldView(password: $viewModel.password)

                        // Error banner — only visible when there is an error
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBannerView(message: errorMessage)
                        }

                        SignInButtonView(
                            isEnabled: viewModel.isSignInEnabled,
                            action: viewModel.signIn
                        )
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 24)
            }
            .background(Color(.systemGroupedBackground))

            // Footer pinned at the bottom
            SecuredByOktaFooterView()
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel(onSignIn: { _, _ in }))
}
