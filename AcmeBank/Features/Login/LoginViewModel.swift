import Foundation
import Combine

/// View-model for the Login screen.
///
/// Owns the editable field state, derived enable logic, and the sign-in
/// action closure.  The closure is injected at call-site so the actual auth
/// integration (Okta, stub, test mock) is swapped without changing this file.
final class LoginViewModel: ObservableObject {
    // MARK: - Published state

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var errorMessage: String?

    // MARK: - Derived

    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Dependencies

    /// Called when the user taps "Sign in" and both fields are non-empty.
    /// Receives `(username, password)`.
    let onSignIn: (String, String) -> Void

    // MARK: - Init

    init(onSignIn: @escaping (String, String) -> Void) {
        self.onSignIn = onSignIn
    }

    // MARK: - Actions

    func signIn() {
        guard isSignInEnabled else { return }
        onSignIn(username, password)
    }
}
