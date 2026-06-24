import SwiftUI

/// App composition root.
/// Presents `LoginView` as the initial screen.
/// The `onSignIn` closure will be replaced with a real auth integration in a future PR.
struct ContentView: View {
    var body: some View {
        LoginView(viewModel: LoginViewModel(onSignIn: { _, _ in }))
    }
}

#Preview {
    ContentView()
}
