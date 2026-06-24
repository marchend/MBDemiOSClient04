import XCTest
@testable import AcmeBank

final class LoginViewModelTests: XCTestCase {

    // =========================================================================
    // MARK: - Existing field-state coverage (pre-Auth-wiring)
    // =========================================================================

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

        // Inject a configProvider that returns .notConfigured so the
        // async Task launched alongside the legacy closure
        // short-circuits without touching the real Okta client. The
        // legacy onSignIn closure still fires synchronously and is
        // what this assertion targets.
        let sut = LoginViewModel(
            configProvider: { .notConfigured(reason: "test") },
            onSignIn: { username, password in
                capturedUsername = username
                capturedPassword = password
            }
        )

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

        let sut = LoginViewModel(
            configProvider: { .notConfigured(reason: "test") },
            onSignIn: { _, _ in invoked = true }
        )

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

    // =========================================================================
    // MARK: - PR 3: DirectAuth integration
    //
    // Fakes (below) keep the test target free of the real Okta SDK
    // and the real Keychain — per the prior lesson "Put the IdP SDK
    // behind a NEUTRAL protocol seam", the protocol contract is the
    // only surface this VM cares about.
    // =========================================================================

    // MARK: Fakes

    /// Scriptable `OktaAuthenticating`. Captures the
    /// `(username, password)` it was called with and either returns a
    /// preset `AuthTokens` or throws a preset `AuthError`.
    private final class FakeAuthClient: OktaAuthenticating {
        enum Outcome {
            case success(AuthTokens)
            case throwError(AuthError)
        }
        var outcome: Outcome
        private(set) var callCount = 0
        private(set) var lastUsername: String?
        private(set) var lastPassword: String?

        init(outcome: Outcome) { self.outcome = outcome }

        func signIn(username: String, password: String) async throws -> AuthTokens {
            callCount += 1
            lastUsername = username
            lastPassword = password
            switch outcome {
            case .success(let t):    return t
            case .throwError(let e): throw e
            }
        }

        func refresh(refreshToken: String) async throws -> AuthTokens {
            throw AuthError.network
        }
    }

    /// In-memory `TokenStore`. Records which save methods were
    /// called and with what value so the keep-signed-in matrix can
    /// assert refresh-token persistence semantics.
    private final class FakeTokenStore: TokenStore {
        private(set) var savedIDToken: String?
        private(set) var savedAccessToken: String?
        private(set) var savedRefreshToken: String?

        func saveIDToken(_ token: String) throws    { savedIDToken = token }
        func saveAccessToken(_ token: String) throws { savedAccessToken = token }
        func saveRefreshToken(_ token: String) throws { savedRefreshToken = token }
        func loadRefreshToken() throws -> String? { savedRefreshToken }
        func clearAll() throws {
            savedIDToken = nil
            savedAccessToken = nil
            savedRefreshToken = nil
        }
    }

    // MARK: - JWT helpers (mirrored from IDTokenDecoderTests)

    /// Build a `header.payload.signature` JWT string with the supplied
    /// JSON as the middle (payload) segment. Header + signature are
    /// placeholders; the decoder only reads the middle.
    private static func makeJWT(payloadJSON: String) -> String {
        let header = base64url(Data("{\"alg\":\"none\"}".utf8))
        let payload = base64url(Data(payloadJSON.utf8))
        let signature = base64url(Data("sig".utf8))
        return "\(header).\(payload).\(signature)"
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// A well-formed JWT with all the standard claims populated.
    private static var validIDToken: String {
        makeJWT(payloadJSON: """
        {"sub":"user-123","name":"Ada Lovelace","email":"ada@acmebank.com","auth_time":1700000000}
        """)
    }

    // MARK: - .notConfigured short-circuit

    func test_signIn_notConfigured_setsBannerCopy_andMakesNoAuthCall() async {
        let auth = FakeAuthClient(outcome: .success(
            AuthTokens(idToken: Self.validIDToken, accessToken: "at", refreshToken: "rt")
        ))
        let store = FakeTokenStore()
        let sut = LoginViewModel(
            authClient: auth,
            tokenStore: store,
            configProvider: { .notConfigured(reason: "missing OKTA_ISSUER") }
        )

        await sut.signIn(username: "ada", password: "pw", keepSignedIn: true)

        XCTAssertEqual(sut.errorMessage,
                       "Okta is not configured on this build — see README")
        XCTAssertEqual(auth.callCount, 0,
                       ".notConfigured must short-circuit before calling the auth client")
        XCTAssertNil(store.savedIDToken)
        XCTAssertNil(store.savedAccessToken)
        XCTAssertNil(store.savedRefreshToken)
        XCTAssertNil(sut.session)
        XCTAssertFalse(sut.isSigningIn,
                       "isSigningIn must remain false on the .notConfigured short-circuit")
    }

    // MARK: - Success — keepSignedIn true

    func test_signIn_success_keepSignedInTrue_persistsAllThreeTokens() async {
        let tokens = AuthTokens(
            idToken: Self.validIDToken,
            accessToken: "access-1",
            refreshToken: "refresh-1"
        )
        let auth = FakeAuthClient(outcome: .success(tokens))
        let store = FakeTokenStore()
        let sut = LoginViewModel(
            authClient: auth,
            tokenStore: store,
            configProvider: Self.configuredProvider
        )

        await sut.signIn(username: "ada", password: "pw", keepSignedIn: true)

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(store.savedIDToken, Self.validIDToken)
        XCTAssertEqual(store.savedAccessToken, "access-1")
        XCTAssertEqual(store.savedRefreshToken, "refresh-1",
                       "keepSignedIn=true must persist the refresh token")
        XCTAssertNotNil(sut.session)
        XCTAssertEqual(sut.session?.userId, "user-123")
        XCTAssertEqual(sut.session?.accessToken, "access-1")
    }

    // MARK: - Success — keepSignedIn false

    func test_signIn_success_keepSignedInFalse_doesNotPersistRefresh() async {
        let tokens = AuthTokens(
            idToken: Self.validIDToken,
            accessToken: "access-2",
            refreshToken: "refresh-2"
        )
        let auth = FakeAuthClient(outcome: .success(tokens))
        let store = FakeTokenStore()
        let sut = LoginViewModel(
            authClient: auth,
            tokenStore: store,
            configProvider: Self.configuredProvider
        )

        await sut.signIn(username: "ada", password: "pw", keepSignedIn: false)

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(store.savedIDToken, Self.validIDToken)
        XCTAssertEqual(store.savedAccessToken, "access-2")
        XCTAssertNil(store.savedRefreshToken,
                     "keepSignedIn=false must NOT persist the refresh token")
        XCTAssertNotNil(sut.session)
    }

    // MARK: - AuthError → copy mapping

    func test_signIn_invalidCredentials_mapsToExactCopy_andClearsSpinner() async {
        let auth = FakeAuthClient(outcome: .throwError(.invalidCredentials))
        let sut = LoginViewModel(
            authClient: auth,
            tokenStore: FakeTokenStore(),
            configProvider: Self.configuredProvider
        )

        await sut.signIn(username: "ada", password: "wrong", keepSignedIn: false)

        XCTAssertEqual(sut.errorMessage,
                       "Incorrect username or password. Please try again.")
        XCTAssertFalse(sut.isSigningIn,
                       "isSigningIn must be cleared after a failed sign-in")
        XCTAssertNil(sut.session)
    }

    func test_signIn_network_mapsToExactCopy_withBracedEmDash() async {
        let auth = FakeAuthClient(outcome: .throwError(.network))
        let sut = LoginViewModel(
            authClient: auth,
            tokenStore: FakeTokenStore(),
            configProvider: Self.configuredProvider
        )

        await sut.signIn(username: "ada", password: "pw", keepSignedIn: false)

        // Assert against the literal em-dash glyph (\u{2014}) so a
        // future copy-edit that drops the dash, switches to a hyphen,
        // or introduces a regular dash is caught at test time.
        XCTAssertEqual(sut.errorMessage,
                       "Couldn't reach Okta \u{2014} check your connection and try again.")
        XCTAssertFalse(sut.isSigningIn)
    }

    func test_signIn_mfaRequired_mapsToExactCopy() async {
        let auth = FakeAuthClient(outcome: .throwError(.mfaRequired))
        let sut = LoginViewModel(
            authClient: auth,
            tokenStore: FakeTokenStore(),
            configProvider: Self.configuredProvider
        )

        await sut.signIn(username: "ada", password: "pw", keepSignedIn: false)

        XCTAssertEqual(sut.errorMessage,
                       "MFA is required but not supported in this build.")
        XCTAssertFalse(sut.isSigningIn)
    }

    // MARK: - Field-edit clears errorMessage

    func test_errorMessage_clearsWhenUsernameEdited() {
        let sut = LoginViewModel(onSignIn: { _, _ in })
        sut.errorMessage = "Incorrect username or password. Please try again."

        sut.username = "new-typed-char"

        XCTAssertNil(sut.errorMessage,
                     "errorMessage must clear when the user starts editing username")
    }

    func test_errorMessage_clearsWhenPasswordEdited() {
        let sut = LoginViewModel(onSignIn: { _, _ in })
        sut.errorMessage = "Incorrect username or password. Please try again."

        sut.password = "new"

        XCTAssertNil(sut.errorMessage,
                     "errorMessage must clear when the user starts editing password")
    }

    // MARK: - isSigningIn toggle

    func test_isSigningIn_togglesTrueThenFalse_acrossSuccess() async {
        // Use a controllable continuation-based fake so we can
        // observe `isSigningIn == true` mid-flight. A plain
        // FakeAuthClient returns synchronously and the toggle is too
        // fast to sample.
        let observer = MidFlightObserver()
        let auth = ObservingAuthClient(observer: observer, result: .success(
            AuthTokens(idToken: Self.validIDToken, accessToken: "at", refreshToken: nil)
        ))
        let sut = LoginViewModel(
            authClient: auth,
            tokenStore: FakeTokenStore(),
            configProvider: Self.configuredProvider
        )
        observer.onSignInCalled = { [weak sut] in
            // Sampled INSIDE the auth call → must be true.
            observer.midFlightIsSigningIn = sut?.isSigningIn ?? false
        }

        XCTAssertFalse(sut.isSigningIn, "must start false")
        await sut.signIn(username: "ada", password: "pw", keepSignedIn: false)

        XCTAssertTrue(observer.midFlightIsSigningIn,
                      "isSigningIn must be true while the auth call is in flight")
        XCTAssertFalse(sut.isSigningIn,
                       "isSigningIn must return to false after success")
        XCTAssertNil(sut.errorMessage)
    }

    func test_isSigningIn_togglesTrueThenFalse_acrossFailure() async {
        let observer = MidFlightObserver()
        let auth = ObservingAuthClient(observer: observer, result: .throwError(.network))
        let sut = LoginViewModel(
            authClient: auth,
            tokenStore: FakeTokenStore(),
            configProvider: Self.configuredProvider
        )
        observer.onSignInCalled = { [weak sut] in
            observer.midFlightIsSigningIn = sut?.isSigningIn ?? false
        }

        await sut.signIn(username: "ada", password: "pw", keepSignedIn: false)

        XCTAssertTrue(observer.midFlightIsSigningIn,
                      "isSigningIn must be true during the auth call even on failure")
        XCTAssertFalse(sut.isSigningIn,
                       "isSigningIn must be cleared by the `defer` after a thrown AuthError")
    }

    // MARK: - Helpers

    /// A configured() OktaConfig with throwaway values — never used by
    /// the fake auth client, but lets the VM skip the .notConfigured
    /// short-circuit so the auth call actually runs.
    private static var configuredProvider: () -> OktaConfig {
        return {
            .configured(
                issuer: URL(string: "https://example.okta.com/oauth2/default")!,
                clientId: "test-client",
                redirectUri: URL(string: "com.acmebank.mobile:/callback")!,
                scopes: ["openid", "profile", "email"]
            )
        }
    }

    /// Holder the mid-flight observation tests share between the
    /// `ObservingAuthClient` fake and the test method.
    private final class MidFlightObserver {
        var midFlightIsSigningIn: Bool = false
        var onSignInCalled: (() -> Void)?
    }

    /// `OktaAuthenticating` fake that calls `observer.onSignInCalled`
    /// INSIDE its `signIn` body before returning, giving the test
    /// method a chance to sample `viewModel.isSigningIn` mid-flight.
    private final class ObservingAuthClient: OktaAuthenticating {
        enum Result {
            case success(AuthTokens)
            case throwError(AuthError)
        }
        let observer: MidFlightObserver
        let result: Result

        init(observer: MidFlightObserver, result: Result) {
            self.observer = observer
            self.result = result
        }

        func signIn(username: String, password: String) async throws -> AuthTokens {
            observer.onSignInCalled?()
            switch result {
            case .success(let t):    return t
            case .throwError(let e): throw e
            }
        }

        func refresh(refreshToken: String) async throws -> AuthTokens {
            throw AuthError.network
        }
    }
}
