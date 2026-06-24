import XCTest
@testable import AcmeBank

final class LoginViewModelTests: XCTestCase {

    // MARK: - isSignInEnabled

    func test_signInDisabled_whenFieldsEmpty() {
        let sut = LoginViewModel(onSignIn: { _, _ in })
        // Both fields start empty
        XCTAssertFalse(sut.isSignInEnabled,
                       "isSignInEnabled must be false when both fields are empty")
    }

    func test_signInDisabled_whenOnlyUsernameEntered() {
        let sut = LoginViewModel(onSignIn: { _, _ in })
        sut.username = "user@acmebank.com"
        XCTAssertFalse(sut.isSignInEnabled,
                       "isSignInEnabled must be false when password is still empty")
    }

    func test_signInDisabled_whenOnlyPasswordEntered() {
        let sut = LoginViewModel(onSignIn: { _, _ in })
        sut.password = "secret"
        XCTAssertFalse(sut.isSignInEnabled,
                       "isSignInEnabled must be false when username is still empty")
    }

    func test_signInEnabled_whenBothFieldsNonEmpty() {
        let sut = LoginViewModel(onSignIn: { _, _ in })
        sut.username = "user@acmebank.com"
        sut.password = "secret"
        XCTAssertTrue(sut.isSignInEnabled,
                      "isSignInEnabled must be true when both fields have text")
    }

    // MARK: - signIn() closure invocation

    func test_signIn_invokesClosureWithCredentials() {
        var capturedUsername: String?
        var capturedPassword: String?

        let sut = LoginViewModel(onSignIn: { username, password in
            capturedUsername = username
            capturedPassword = password
        })

        sut.username = "user@acmebank.com"
        sut.password = "secret123"
        sut.signIn()

        XCTAssertEqual(capturedUsername, "user@acmebank.com",
                       "onSignIn should receive the entered username")
        XCTAssertEqual(capturedPassword, "secret123",
                       "onSignIn should receive the entered password")
    }

    func test_signIn_doesNotInvokeClosure_whenFieldsEmpty() {
        var invoked = false

        let sut = LoginViewModel(onSignIn: { _, _ in
            invoked = true
        })

        // Fields are empty → isSignInEnabled is false
        sut.signIn()

        XCTAssertFalse(invoked,
                       "onSignIn must not be called when isSignInEnabled is false")
    }

    // MARK: - errorMessage

    func test_errorMessage_isNilByDefault() {
        let sut = LoginViewModel(onSignIn: { _, _ in })
        XCTAssertNil(sut.errorMessage,
                     "errorMessage should be nil when no error has been set")
    }

    func test_errorMessage_updatesView_whenSet() {
        let sut = LoginViewModel(onSignIn: { _, _ in })
        sut.errorMessage = "Invalid credentials"
        XCTAssertEqual(sut.errorMessage, "Invalid credentials",
                       "errorMessage should reflect the assigned value")
    }
}
