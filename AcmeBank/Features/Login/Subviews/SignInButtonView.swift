import SwiftUI

/// Full-width "Sign in" button styled in Acme Navy.
struct SignInButtonView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        Button {
            viewModel.signIn()
        } label: {
            Text("Sign in")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.acmeNavy)
                .cornerRadius(8)
                .opacity(viewModel.isSignInEnabled ? 1.0 : 0.4)
        }
        .disabled(!viewModel.isSignInEnabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        SignInButtonView(viewModel: LoginViewModel(onSignIn: { _, _ in }))
        SignInButtonView(viewModel: {
            let vm = LoginViewModel(onSignIn: { _, _ in })
            vm.username = "user@example.com"
            vm.password = "secret"
            return vm
        }())
    }
    .padding()
}
