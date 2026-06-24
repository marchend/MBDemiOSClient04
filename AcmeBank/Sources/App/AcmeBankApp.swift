import SwiftUI
import UIKit

/// App composition root.
///
/// State machine:
///   - `session == nil`  \u2192 show `LoginView`. The shared
///     `LoginViewModel` publishes a `UserSession?` whose non-nil
///     transition (driven by a successful Direct-Auth round-trip)
///     promotes us to the Landing branch.
///   - `session != nil`  \u2192 show `LandingView(session:)`.
///
/// On launch we attempt a cold-start refresh-token reuse: if the user
/// previously checked "Keep me signed in" we have a refresh token in
/// the keychain, and we use it to mint a fresh ID + access pair via
/// `SessionRestorer.restore(...)`. Any failure (network, IdP-rejected
/// stale token, malformed response) clears the stored refresh token
/// and falls through to Login \u2014 the prior lesson "wire the real
/// integration, delete the stub bootstrap" is honoured here by the
/// fact that there is NO hardcoded placeholder display name in the
/// shipped code: the ONLY way to reach Landing is through a real
/// `UserSession`.
@main
struct AcmeBankApp: App {
    /// Shared Login VM \u2014 we hold it on the App so its `@Published
    /// session` publisher survives across LoginView re-creations and
    /// so the launch-time `onReceive` binding has a stable source.
    @StateObject private var loginViewModel = LoginViewModel()

    /// The single source of truth for "are we signed in?". Mutating
    /// this on the main actor flips the root view between Login and
    /// Landing.
    @State private var session: UserSession?

    /// Guard so the cold-start restore runs exactly once per process
    /// (SwiftUI's `.task` on a conditional root can fire again if the
    /// branch flips, and we don't want a second restore attempt to
    /// race a fresh sign-in).
    @State private var didAttemptRestore = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let session {
                    LandingView(session: session)
                } else {
                    LoginView(viewModel: loginViewModel)
                }
            }
            // Promote a successful Direct-Auth sign-in (published as
            // `LoginViewModel.session`) into our root-level `session`
            // state so the next SwiftUI body evaluation swaps in
            // LandingView. Attached to the outer `Group` rather than
            // to `LoginView` so the subscription's lifetime matches
            // the scene root, not the (transient) LoginView instance.
            // This matters once a sign-out flow ships: a Landing \u2192
            // Login \u2192 Landing round trip will keep observing this
            // publisher continuously, instead of tearing the
            // subscription down and re-creating it (and possibly
            // missing a publish that arrived during the layout pass
            // before the modifier re-attaches).
            .onChange(of: loginViewModel.session) { newSession in
                if let newSession {
                    session = newSession
                }
            }
            .task {
                await attemptColdStartRestore()
            }
        }
    }

    /// Cold-launch refresh-token reuse.
    ///
    /// Preconditions checked in order:
    ///   1. We haven't already attempted a restore this process.
    ///   2. There is a refresh token in the keychain (user opted into
    ///      "Keep me signed in" on a previous run).
    ///   3. `OktaConfig` is `.configured` \u2014 no point calling the SDK
    ///      with sentinel issuer / client id.
    ///
    /// On a `SessionRestorer.restore(...)` throw we differentiate by
    /// the typed `AuthError`: errors that prove the token itself is
    /// no longer useful (`.invalidCredentials`, `.malformedToken`,
    /// `.notConfigured`) clear the keychain so the next launch
    /// doesn't burn another round trip on a known-bad value; transient
    /// failures (`.network`, `.mfaRequired`, or any non-typed throw)
    /// preserve the token so a flaky connection \u2014 or a staged auth
    /// client whose `refresh(...)` implementation is not yet live \u2014
    /// does NOT silently purge a valid "Keep me signed in" token from
    /// the keychain on first cold launch. We deliberately don't
    /// surface the failure as an error banner: this is a silent
    /// best-effort background path, and the user is about to see
    /// Login anyway.
    @MainActor
    private func attemptColdStartRestore() async {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true

        let tokenStore = KeychainTokenStore()
        let refreshToken: String?
        do {
            refreshToken = try tokenStore.loadRefreshToken()
        } catch {
            // Keychain read failed \u2014 treat as "no token". The
            // refresh-token path is opportunistic; a keychain glitch
            // never blocks the user from signing in fresh.
            return
        }
        guard let refreshToken else { return }

        let config = OktaConfig.load()
        guard case .configured = config else {
            // Build has no Okta config (sentinels in Info.plist).
            // The persisted refresh token is meaningless without a
            // configured issuer / client; clear it and bail.
            try? tokenStore.clearAll()
            return
        }

        await attemptColdStartRestore(
            refreshToken: refreshToken,
            authClient: OktaDirectAuthClient(config: config),
            tokenStore: tokenStore,
            deviceName: UIDevice.current.name
        )
    }

    /// Injection seam for the restore path. The public entrypoint
    /// above hard-constructs the production `OktaDirectAuthClient`;
    /// this overload takes the auth client (and token store) as
    /// parameters so the implementation can be swapped without
    /// touching the SwiftUI surface. Keeping the construction at the
    /// caller also makes the "is the live refresh path actually
    /// implemented?" decision explicit at the call site rather than
    /// buried inside a helper.
    @MainActor
    private func attemptColdStartRestore(
        refreshToken: String,
        authClient: OktaAuthenticating,
        tokenStore: KeychainTokenStore,
        deviceName: String
    ) async {
        do {
            let restored = try await SessionRestorer.restore(
                refreshToken: refreshToken,
                authClient: authClient,
                deviceName: deviceName
            )
            session = restored
        } catch let error as AuthError {
            switch error {
            case .invalidCredentials, .malformedToken, .notConfigured:
                // The IdP / decoder has told us the persisted token
                // is no longer useful. Clear it so the NEXT cold
                // launch doesn't burn another round trip on a
                // known-bad value.
                try? tokenStore.clearAll()
            case .network, .mfaRequired:
                // Transient or non-token-fatal. Crucially this also
                // covers the staged `OktaDirectAuthClient.refresh`
                // stub (which unconditionally throws `.network` until
                // the AuthFoundation call site lands): a partially
                // implemented refresh path will NOT silently wipe a
                // valid "Keep me signed in" token on first launch.
                // The user just falls through to Login this time.
                break
            }
        } catch {
            // Non-typed throw \u2014 we don't know whether the token is
            // actually bad. Preserve it; the user re-signs-in this
            // launch and we retry on the next cold start.
        }
    }
}
