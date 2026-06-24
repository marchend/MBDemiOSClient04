import SwiftUI

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
                        // Promote a successful Direct-Auth sign-in
                        // (published as `LoginViewModel.session`) into
                        // our root-level `session` state so the next
                        // SwiftUI body evaluation swaps in LandingView.
                        .onReceive(loginViewModel.$session.compactMap { $0 }) { newSession in
                            session = newSession
                        }
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
    /// On any throw from `SessionRestorer.restore(...)` we clear the
    /// stale tokens and stay on Login. We deliberately don't surface
    /// the failure as an error banner: this is a silent best-effort
    /// background path, and the user is about to see Login anyway.
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

        let authClient = OktaDirectAuthClient(config: config)
        do {
            let restored = try await SessionRestorer.restore(
                refreshToken: refreshToken,
                authClient: authClient
            )
            session = restored
        } catch {
            // Any failure \u2014 network, IdP-rejected stale refresh,
            // malformed response \u2014 means the persisted token is no
            // longer useful. Clear it so the NEXT cold launch doesn't
            // burn another round trip on the same stale value.
            try? tokenStore.clearAll()
        }
    }
}
