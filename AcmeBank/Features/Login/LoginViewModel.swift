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
/// Auth-layer wiring continue to compile. The closure is NO LONGER
/// invoked alongside the async auth flow when the user taps Sign In
/// — see the note on the zero-arg `signIn()` for the rationale.
/// New callers should drive `signIn(username:password:keepSignedIn:)`
/// directly.
///
/// NOTE on actor isolation: the class itself is NOT `@MainActor` (so the
/// synchronous XCTest cases can construct it and exercise the derived
/// `isSignInEnabled` / zero-arg `signIn()` trigger without isolation
/// diagnostics), but the async `signIn(username:password:keepSignedIn:)`
/// IS `@MainActor`. That async body mutates `@Published` state
/// (`session`, `errorMessage`, `isSigningIn`) and is launched from a
/// `Task` inside the zero-arg trigger — without main-actor isolation it
/// runs on a background executor and SwiftUI logs "Publishing changes
/// from background threads is not allowed", dropping the `session`
/// publish so a *successful* sign-in never advances past Login. This
/// mirrors `HomeViewModel`, where only `load()` / `signOut()` carry the
/// annotation for the same reason.
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
    ///
    /// NOTE: as of this review-feedback pass the zero-arg `signIn()`
    /// no longer fires this closure — it would cause a double-trigger
    /// alongside the async Direct-Auth path. The property is retained
    /// only so the existing call sites compile; once the composition
    /// root migrates to driving the async method directly, this field
    /// and the trailing `onSignIn:` parameter will be removed.
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
        // Resolve the config ONCE through the supplied `configProvider`
        // so the fallback live adapter and the per-sign-in
        // short-circuit guard always agree on the same config value.
        // Previously the init read `OktaConfig.load()` directly here
        // and then `configProvider` (defaulting to a SECOND
        // `OktaConfig.load()` call) was used at sign-in time — fine in
        // production but allowed an injected `configProvider` (e.g. a
        // test or preview supplying `.notConfigured`) to disagree with
        // the live adapter built from `Bundle.main`.
        let resolvedConfig = configProvider()
        self.authClient = authClient ?? OktaDirectAuthClient(config: resolvedConfig)
        self.tokenStore = tokenStore ?? KeychainTokenStore()
        self.configProvider = configProvider
        self.onSignIn = onSignIn
    }

    // MARK: - Actions

    /// The UI's existing zero-arg sign-in trigger (called from the
    /// Sign In button).
    ///
    /// Behaviour:
    ///   1. Synchronously guards on `isSignInEnabled` AND on
    ///      `!isSigningIn` so rapid double-taps before the async body
    ///      has flipped `isSigningIn = true` cannot launch two
    ///      concurrent auth calls against the same credentials.
    ///   2. Sets `isSigningIn = true` SYNCHRONOUSLY (the async path
    ///      sets it again, which is a harmless no-op) so the
    ///      check-and-set is race-free.
    ///   3. Launches the async Direct-Auth flow with
    ///      `keepSignedIn: false`. The legacy `onSignIn` closure is
    ///      intentionally NOT fired here — firing it alongside the
    ///      async Task produced a double-trigger and made the
    ///      user-visible "one tap = one auth call" contract untrue.
    ///
    /// TODO(MBE2EDEM04): wire the "Keep me signed in" toggle from
    /// the UI through to `keepSignedIn` once the companion UI story
    /// surfaces the toggle state. The async method already honours
    /// the parameter; this zero-arg call site is the only place
    /// hardcoding `false`.
    func signIn() {
        guard isSignInEnabled, !isSigningIn else { return }
        // Synchronous check-and-set so a second tap arriving before
        // the Task body runs cannot pass the guard above. The async
        // body re-assigns this to `true` and clears it in `defer`.
        isSigningIn = true
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
    ///
    /// Annotated `@MainActor` so every `@Published` mutation below
    /// (`errorMessage`, `isSigningIn`, `session`) is delivered on the
    /// main thread — including when the zero-arg `signIn()` launches this
    /// from a background `Task`. Without it SwiftUI logs "Publishing
    /// changes from background threads is not allowed" and the `session`
    /// publish can be dropped, leaving a successful sign-in stuck on the
    /// Login screen.
    @MainActor
    func signIn(username: String, password: String, keepSignedIn: Bool) async {
        // .notConfigured precheck — surface the configured-on-this-build
        // banner WITHOUT making a network call or flipping the spinner.
        // (Em-dash is a literal Unicode character, NOT a `\uXXXX`
        // escape — Swift requires braced `\u{2014}` and we'd rather
        // just write the glyph.)
        if case .notConfigured = configProvider() {
            errorMessage = "Okta is not configured on this build — see README"
            // If the zero-arg `signIn()` flipped `isSigningIn = true`
            // synchronously before launching this Task, we must clear
            // it here on the short-circuit path — we return BEFORE
            // entering the `defer` block below.
            isSigningIn = false
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
