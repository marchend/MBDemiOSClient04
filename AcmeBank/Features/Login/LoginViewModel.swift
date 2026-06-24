import Foundation
import Combine
import UIKit

/// View-model for the Login screen.
///
/// Owns the editable field state, derived enable logic, and the
/// sign-in action. As of this PR the VM also drives the actual
/// Direct-Auth sign-in flow against the Auth layer (`OktaAuthenticating`
/// + `TokenStore` + `OktaConfig` provider injected via init).
///
/// Dependency-injection seams (`authClient`, `tokenStore`,
/// `configProvider`) keep the test target free of the real Keychain
/// and the real Okta SDK — production call sites use the defaulted
/// concrete implementations from the Auth layer.
///
/// The legacy closure-based `onSignIn(username, password)` initializer
/// is preserved so existing call sites and tests that pre-date the
/// Auth-layer wiring continue to compile. The closure is invoked
/// alongside the async auth flow when the user taps Sign In; new
/// callers should drive `signIn(username:password:keepSignedIn:)`
/// directly.
///
/// NOTE on actor isolation: the class is deliberately NOT `@MainActor`
/// so the existing synchronous XCTest cases can construct it and
/// mutate fields off the main thread without isolation diagnostics.
/// The async `signIn(username:password:keepSignedIn:)` body mutates
/// `@Published` properties from whatever context the caller chose;
/// SwiftUI's bindings are itself main-actor isolated so production UI
/// updates ride the standard publisher path. If a future PR adopts
/// strict Swift 6 concurrency, this class becomes a candidate for
/// `@MainActor`.
final class LoginViewModel: ObservableObject {
    // MARK: - Published state

    /// Editable username field. Clears any visible error on edit so
    /// the user isn't shouted at while they're correcting their typo.
    @Published var username: String = "" {
        didSet { if oldValue != username { errorMessage = nil } }
    }

    /// Editable password field. Same edit-clears-error behavior as
    /// `username`.
    @Published var password: String = "" {
        didSet { if oldValue != password { errorMessage = nil } }
    }

    /// User-facing error copy. Cleared on field edit and on the start
    /// of a new sign-in attempt.
    @Published var errorMessage: String?

    /// True while a sign-in attempt is in flight. The UI binds the
    /// spinner / disabled state off this. Always returns to false in
    /// a `defer` regardless of success / failure / thrown error.
    @Published var isSigningIn: Bool = false

    /// Published when a sign-in succeeds and the ID token decodes
    /// cleanly. A later PR (Landing composition root) observes this
    /// to advance navigation; in this PR it just surfaces the value.
    @Published var session: UserSession?

    // MARK: - Derived

    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Dependencies

    /// Live Okta Direct-Auth seam (see `OktaAuthenticating`). Defaults
    /// to the real adapter constructed from the runtime `OktaConfig`.
    private let authClient: OktaAuthenticating

    /// Token persistence seam (see `TokenStore`). Defaults to the real
    /// `KeychainTokenStore`.
    private let tokenStore: TokenStore

    /// Returns the current `OktaConfig`. Wrapped in a closure so
    /// tests can substitute `.notConfigured` without touching
    /// `Bundle.main`, and so the value is re-read on every sign-in
    /// (no stale config captured at init).
    private let configProvider: () -> OktaConfig

    /// Legacy closure preserved for back-compat: existing tests and
    /// the composition root construct the VM with
    /// `LoginViewModel(onSignIn: { _, _ in })`. New code should use
    /// the async `signIn(username:password:keepSignedIn:)` method.
    let onSignIn: (String, String) -> Void

    // MARK: - Init

    /// Production initializer.
    ///
    /// All three Auth-layer deps default to the real implementations so
    /// the composition root needs no knowledge of them. Tests construct
    /// the VM with custom fakes for each.
    init(
        authClient: OktaAuthenticating? = nil,
        tokenStore: TokenStore? = nil,
        configProvider: @escaping () -> OktaConfig = { OktaConfig.load() },
        onSignIn: @escaping (String, String) -> Void = { _, _ in }
    ) {
        // Defer constructing the live `OktaDirectAuthClient` until we
        // know the caller didn't inject a fake. The live adapter
        // reads `OktaConfig.load()` eagerly off `Bundle.main`, which
        // is fine in production but pointless to do in tests that
        // inject a fake `OktaAuthenticating`.
        self.authClient = authClient ?? OktaDirectAuthClient(config: OktaConfig.load())
        self.tokenStore = tokenStore ?? KeychainTokenStore()
        self.configProvider = configProvider
        self.onSignIn = onSignIn
    }

    // MARK: - Actions

    /// The UI's existing zero-arg sign-in trigger (called from the
    /// Sign In button). Guards on `isSignInEnabled`, invokes the
    /// legacy `onSignIn` closure for back-compat, then launches the
    /// async auth flow with `keepSignedIn: false` (the toggle is
    /// owned by the UI story; defaulting here keeps the existing call
    /// site working until that wiring lands).
    func signIn() {
        guard isSignInEnabled else { return }
        onSignIn(username, password)
        let u = username
        let p = password
        Task { [weak self] in
            await self?.signIn(username: u, password: p, keepSignedIn: false)
        }
    }

    /// Run a Direct-Auth sign-in against the injected `authClient`,
    /// decode the ID token, persist the resulting tokens, and publish
    /// a `UserSession` on success.
    ///
    /// Error handling matches the bootstrap spec:
    ///   - `.notConfigured` short-circuits with the configured-on-this-build
    ///     banner copy — NO network call is made.
    ///   - `.invalidCredentials` / `.network` / `.mfaRequired` map to
    ///     the three required copy strings, exact punctuation.
    ///   - Any other thrown error (including `.malformedToken`) collapses
    ///     to the network copy as a safe default.
    ///
    /// `isSigningIn` is always cleared in a `defer` so a thrown error
    /// or a guard-return cannot leave the spinner stuck on.
    func signIn(username: String, password: String, keepSignedIn: Bool) async {
        // .notConfigured precheck — surface the configured-on-this-build
        // banner WITHOUT making a network call or flipping the spinner.
        // (Em-dash is a literal Unicode character, NOT a `\uXXXX`
        // escape — Swift requires braced `\u{2014}` and we'd rather
        // just write the glyph.)
        if case .notConfigured = configProvider() {
            errorMessage = "Okta is not configured on this build — see README"
            return
        }

        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let tokens = try await authClient.signIn(username: username, password: password)

            // ID token must be present for us to build a UserSession.
            // Treat absence the same as a malformed token — both are
            // post-SDK plumbing bugs, not credential failures.
            guard let idToken = tokens.idToken else {
                errorMessage = "Couldn't reach Okta — check your connection and try again."
                return
            }

            let claims: IDTokenClaims
            do {
                claims = try IDTokenDecoder.decode(idToken)
            } catch {
                // Post-SDK decode failure — surface the network copy
                // (our safe default) so we don't lie about the cause
                // without inventing a brand-new banner string. The
                // typed error class is logged for diagnostics by the
                // SDK adapter / decoder; the UI just sees one of the
                // three documented strings.
                errorMessage = "Couldn't reach Okta — check your connection and try again."
                return
            }

            // Persist tokens — best-effort cache. Per the prior lesson
            // "treat keychain writes as a cache, not a hard
            // requirement", we never let a Keychain failure (e.g.
            // simulator `errSecMissingEntitlement`) turn a successful
            // sign-in into a failure. ID + access always persist;
            // refresh only when the user opted into Keep Me Signed In.
            do { try tokenStore.saveIDToken(idToken) } catch { /* best-effort */ }
            do { try tokenStore.saveAccessToken(tokens.accessToken) } catch { /* best-effort */ }
            if keepSignedIn, let refresh = tokens.refreshToken {
                do { try tokenStore.saveRefreshToken(refresh) } catch { /* best-effort */ }
            }

            session = UserSession(
                userId: claims.sub,
                displayName: claims.name ?? claims.email ?? claims.sub,
                email: claims.email ?? "",
                accessToken: tokens.accessToken,
                authTimestamp: claims.auth_time ?? Date(),
                deviceName: UIDevice.current.name
            )
        } catch let error as AuthError {
            errorMessage = Self.copy(for: error)
        } catch {
            // Any non-AuthError that escapes from `authClient.signIn`
            // is, by the protocol contract, a bug — but we still
            // refuse to lie with a credential-error banner. The
            // network copy is our documented safe default.
            errorMessage = "Couldn't reach Okta — check your connection and try again."
        }
    }

    // MARK: - Copy mapping

    /// The three required user-facing copy strings, matched
    /// character-for-character against the spec. Any drift in
    /// punctuation here is a bootstrap-spec violation — the
    /// `LoginViewModelTests` matrix asserts the exact strings.
    private static func copy(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials:
            return "Incorrect username or password. Please try again."
        case .network:
            return "Couldn't reach Okta — check your connection and try again."
        case .mfaRequired:
            return "MFA is required but not supported in this build."
        case .notConfigured:
            // .notConfigured is normally short-circuited before the
            // auth call, but if an SDK adapter ever surfaces it from
            // inside `signIn` we still want a sensible banner.
            return "Okta is not configured on this build — see README"
        case .malformedToken:
            // Safe-default to the network copy — see the body of
            // `signIn(username:password:keepSignedIn:)` for rationale.
            return "Couldn't reach Okta — check your connection and try again."
        }
    }
}
