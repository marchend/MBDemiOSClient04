import XCTest
import Combine
@testable import AcmeBank

final class HomeViewModelTests: XCTestCase {

    // MARK: - Fakes

    /// Scriptable `HomeRepositoryProtocol`.
    ///
    /// On each `fetchHome()` call it dequeues the next `Outcome` from
    /// `outcomes`. If the queue is empty it falls back to the
    /// `bankuser.one` fixture so tests that only call once don't need
    /// to specify every outcome.
    private final class FakeHomeRepository: HomeRepositoryProtocol {
        enum Outcome {
            case success(HomeDashboard)
            case failure(HomeError)
        }

        var outcomes: [Outcome]

        init(outcomes: [Outcome] = []) {
            self.outcomes = outcomes
        }

        func fetchHome() async throws -> HomeDashboard {
            guard !outcomes.isEmpty else {
                return StubHomeRepository.bankuserOneFixture
            }
            let next = outcomes.removeFirst()
            switch next {
            case .success(let d):   return d
            case .failure(let e):   throw e
            }
        }
    }

    /// `HomeRepositoryProtocol` that suspends until the test signals
    /// it to resume. Used to observe the `.loading` state mid-flight.
    ///
    /// Coordination is handled through two `AsyncStream`-backed
    /// channels so there is no race between the test and the task:
    ///  - `fetchHome()` yields to `didEnterStream` the moment it is
    ///    entered (before suspending), then blocks on `resumeStream`.
    ///  - The test awaits `waitUntilEntered()` which consumes the
    ///    first element from `didEnterStream` — deterministic, no
    ///    sleeps required.
    private final class SuspendingRepository: HomeRepositoryProtocol {
        private let result: FakeHomeRepository.Outcome

        // Channel: repository → test ("I have entered fetchHome")
        private let didEnterStream: AsyncStream<Void>
        private let didEnterContinuation: AsyncStream<Void>.Continuation

        // Channel: test → repository ("you may now complete")
        private let resumeStream: AsyncStream<Void>
        private let resumeContinuation: AsyncStream<Void>.Continuation

        init(result: FakeHomeRepository.Outcome = .success(StubHomeRepository.bankuserOneFixture)) {
            self.result = result

            var diec: AsyncStream<Void>.Continuation!
            self.didEnterStream = AsyncStream { diec = $0 }
            self.didEnterContinuation = diec

            var rc: AsyncStream<Void>.Continuation!
            self.resumeStream = AsyncStream { rc = $0 }
            self.resumeContinuation = rc
        }

        func fetchHome() async throws -> HomeDashboard {
            // Notify the test that we have entered — happens before
            // the actual suspension so the test sees .loading is set.
            didEnterContinuation.yield()

            // Block until the test calls resume().
            for await _ in resumeStream { break }

            switch result {
            case .success(let d): return d
            case .failure(let e): throw e
            }
        }

        /// Awaits until `fetchHome()` has been called. Returns as soon
        /// as the repository side signals entry, guaranteeing that
        /// `HomeViewModel.load()` has already set `state = .loading`
        /// before this returns.
        func waitUntilEntered() async {
            for await _ in didEnterStream { break }
        }

        /// Unblocks the suspended `fetchHome()` call.
        func resume() {
            resumeContinuation.yield()
        }
    }

    /// In-memory `TokenStore`. Records whether `clearAll()` was called.
    private final class FakeTokenStore: TokenStore {
        private(set) var clearAllCallCount = 0

        func saveIDToken(_ token: String) throws {}
        func saveAccessToken(_ token: String) throws {}
        func saveRefreshToken(_ token: String) throws {}
        func loadRefreshToken() throws -> String? { nil }
        func clearAll() throws {
            clearAllCallCount += 1
        }
    }

    // MARK: - Helpers

    private static let stubSession = UserSession(
        userId: "test-user",
        displayName: "Test User",
        email: "test@acmebank.com",
        accessToken: "test-access-token",
        authTimestamp: Date(timeIntervalSince1970: 0),
        deviceName: "Test Device"
    )

    // MARK: - Happy path

    func test_happyPath_populatesLoadedState() async {
        let repo = FakeHomeRepository(
            outcomes: [.success(StubHomeRepository.bankuserOneFixture)]
        )
        var signOutCalled = false
        let sut = HomeViewModel(
            session: Self.stubSession,
            repository: repo,
            onSignOut: { signOutCalled = true }
        )

        await sut.load()

        guard case .loaded(let dashboard) = sut.state else {
            XCTFail("Expected .loaded state, got \(sut.state)")
            return
        }
        XCTAssertEqual(dashboard.customer.displayName, "Alex Bankuser")
        XCTAssertEqual(dashboard.accounts.count, 4)
        XCTAssertEqual(dashboard.recentTransactions.count, 3)
        XCTAssertFalse(signOutCalled)
    }

    // MARK: - Loading state

    func test_loadingState_setsDuringFetch() async {
        let suspending = SuspendingRepository()
        let sut = HomeViewModel(
            session: Self.stubSession,
            repository: suspending,
            onSignOut: {}
        )

        XCTAssertEqual(sut.state, .idle, "Must start idle")

        // Kick off load() on a background task so we can observe mid-flight.
        let loadTask = Task { await sut.load() }

        // Wait deterministically for fetchHome() to have been entered.
        // `SuspendingRepository.fetchHome()` signals entry via an
        // AsyncStream before suspending, so by the time this returns
        // `HomeViewModel.load()` has already executed `state = .loading`
        // and the repository is blocked waiting for `resume()`.
        // No time-based sleep needed — this is a structured rendezvous.
        await suspending.waitUntilEntered()

        XCTAssertEqual(sut.state, .loading, "State must be .loading while fetch is suspended")

        // Allow the fetch to complete.
        suspending.resume()
        await loadTask.value

        guard case .loaded = sut.state else {
            XCTFail("Expected .loaded after resume, got \(sut.state)")
            return
        }
    }

    // MARK: - 401 / Unauthorized

    func test_401_triggersSignOut() async {
        let repo = FakeHomeRepository(outcomes: [.failure(.unauthorized)])
        let tokenStore = FakeTokenStore()

        let signOutExpectation = expectation(description: "onSignOut called")
        let sut = HomeViewModel(
            session: Self.stubSession,
            repository: repo,
            onSignOut: { signOutExpectation.fulfill() },
            tokenStore: tokenStore
        )

        await sut.load()

        await fulfillment(of: [signOutExpectation], timeout: 1.0)
        XCTAssertEqual(tokenStore.clearAllCallCount, 1,
                       "clearAll() must be called exactly once on 401")
    }

    // MARK: - 5xx / Network failure

    func test_5xx_setsErrorState() async {
        let underlyingError = URLError(.badServerResponse)
        let repo = FakeHomeRepository(
            outcomes: [.failure(.networkFailure(underlyingError))]
        )
        let sut = HomeViewModel(
            session: Self.stubSession,
            repository: repo,
            onSignOut: {}
        )

        await sut.load()

        guard case .error(let err) = sut.state else {
            XCTFail("Expected .error state, got \(sut.state)")
            return
        }
        XCTAssertEqual(err, .networkFailure(underlyingError))
    }

    // MARK: - Retry

    func test_retry_invokesLoadAgain() async {
        let underlyingError = URLError(.notConnectedToInternet)
        let repo = FakeHomeRepository(outcomes: [
            .failure(.networkFailure(underlyingError)),
            .success(StubHomeRepository.bankuserOneFixture)
        ])
        let sut = HomeViewModel(
            session: Self.stubSession,
            repository: repo,
            onSignOut: {}
        )

        // First call — should fail.
        await sut.load()
        guard case .error = sut.state else {
            XCTFail("Expected .error on first load, got \(sut.state)")
            return
        }

        // Second call — should succeed (next outcome is .success).
        await sut.load()
        guard case .loaded(let dashboard) = sut.state else {
            XCTFail("Expected .loaded on retry, got \(sut.state)")
            return
        }
        XCTAssertEqual(dashboard.customer.displayName, "Alex Bankuser")
    }

    // MARK: - signOut

    /// `signOut()` is `@MainActor`-isolated, so the test must be async
    /// to hop onto the main actor before calling it.  Using
    /// `MainActor.run` makes the isolation explicit and keeps the
    /// test body synchronous-feeling while satisfying the Swift
    /// Concurrency requirement.
    func test_signOut_clearsKeychainAndCallsCallback() async {
        let tokenStore = FakeTokenStore()
        let signOutExpectation = expectation(description: "onSignOut called")

        let sut = HomeViewModel(
            session: Self.stubSession,
            repository: FakeHomeRepository(),
            onSignOut: { signOutExpectation.fulfill() },
            tokenStore: tokenStore
        )

        // signOut() is @MainActor — call it through MainActor.run to
        // satisfy the concurrency requirement.
        await MainActor.run {
            sut.signOut()
        }

        await fulfillment(of: [signOutExpectation], timeout: 1.0)
        XCTAssertEqual(tokenStore.clearAllCallCount, 1,
                       "clearAll() must be called once when signOut() is invoked")
    }
}
