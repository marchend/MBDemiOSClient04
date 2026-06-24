import Foundation

/// View-state for the Home screen.
public enum HomeViewState: Equatable {
    case idle
    case loading
    case loaded(HomeDashboard)
    case error(HomeError)
}

/// ViewModel for the Home/Dashboard screen.
///
/// Drives a four-state machine (`idle → loading → loaded | error`).
/// On HTTP 401 the ViewModel clears the Keychain and fires `onSignOut`
/// so the app coordinator can navigate back to Login.
///
/// NOT `@MainActor` on the class — only `load()` is `@MainActor` so
/// that `@Published` mutations reach the UI on the main thread. This
/// mirrors the pattern established by `LoginViewModel` and avoids
/// forcing every async collaborator to also be MainActor.
public final class HomeViewModel: ObservableObject {

    // MARK: - Published state

    @Published public var state: HomeViewState = .idle

    // MARK: - Dependencies

    private let session: UserSession
    private let repository: HomeRepositoryProtocol
    private let onSignOut: () -> Void
    private let tokenStore: TokenStore

    // MARK: - Init

    /// Production initializer.
    ///
    /// - Parameters:
    ///   - session: Authenticated user session supplying the Bearer
    ///     token for BFF requests.
    ///   - repository: Data source for the home dashboard. Defaults
    ///     to `BFFHomeRepository` backed by the shared `URLSession`.
    ///   - onSignOut: Closure invoked when the user signs out (either
    ///     manually or as a result of a 401 response). The coordinator
    ///     should navigate back to Login from here.
    ///   - tokenStore: Keychain token store used to clear tokens on
    ///     sign-out. Defaults to the production `KeychainTokenStore`.
    public init(
        session: UserSession,
        repository: HomeRepositoryProtocol? = nil,
        onSignOut: @escaping () -> Void,
        tokenStore: TokenStore = KeychainTokenStore()
    ) {
        self.session = session
        self.repository = repository ?? BFFHomeRepository(session: session)
        self.onSignOut = onSignOut
        self.tokenStore = tokenStore
    }

    // MARK: - Actions

    /// Fetch the home dashboard from the repository.
    ///
    /// State transitions:
    ///   - Sets `.loading` immediately on entry.
    ///   - Sets `.loaded(dashboard)` on success.
    ///   - On `HomeError.unauthorized`: clears Keychain then calls
    ///     `onSignOut()`.
    ///   - On any other error: sets `.error(error)`.
    @MainActor
    public func load() async {
        state = .loading
        do {
            let dashboard = try await repository.fetchHome()
            state = .loaded(dashboard)
        } catch let error as HomeError {
            switch error {
            case .unauthorized:
                clearKeychainAndSignOut()
            case .networkFailure:
                state = .error(error)
            }
        } catch {
            state = .error(.networkFailure(error))
        }
    }

    /// Manually sign the user out.
    ///
    /// Clears the Keychain and fires `onSignOut`. The state machine
    /// is left in its current state because the coordinator will
    /// navigate away immediately.
    public func signOut() {
        clearKeychainAndSignOut()
    }

    // MARK: - Private

    /// Clear all tokens from the Keychain and invoke the sign-out
    /// callback. `clearAll()` failures are silently swallowed — a
    /// keychain glitch must not prevent the navigation to Login.
    private func clearKeychainAndSignOut() {
        try? tokenStore.clearAll()
        onSignOut()
    }
}
