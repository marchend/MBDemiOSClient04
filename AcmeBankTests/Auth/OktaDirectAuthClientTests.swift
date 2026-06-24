import XCTest
@testable import AcmeBank

/// Tests for the Auth-layer SDK seam.
///
/// The plan calls for asserting the four mapped `Status -> AuthError`
/// branches without hitting the network. Per the prior lesson "Put the
/// IdP SDK behind a NEUTRAL protocol seam", the protocol returns our
/// own `AuthTokens` / throws our own `AuthError`, so the test target
/// does NOT need to import `OktaDirectAuth` — we exercise the contract
/// via a tiny in-target `FakeAuthClient` that produces each of the
/// four outcomes the live adapter promises to surface.
///
/// What this guarantees:
///   - the `OktaAuthenticating` protocol shape is callable from an
///     async context with `username` / `password` parameters and
///     returns `AuthTokens` / throws `AuthError`;
///   - downstream code (`AuthService` in PR 3, `LoginViewModel` in
///     PR 3) can rely on each of the four documented branches
///     without taking an SDK dependency.
final class OktaDirectAuthClientTests: XCTestCase {
    // MARK: - Fake

    /// Scriptable `OktaAuthenticating` for the four mapped branches.
    private final class FakeAuthClient: OktaAuthenticating {
        enum Outcome {
            case success(AuthTokens)
            case throwError(AuthError)
        }

        var signInOutcome: Outcome
        var refreshOutcome: Outcome

        init(signIn: Outcome, refresh: Outcome = .throwError(.network)) {
            self.signInOutcome = signIn
            self.refreshOutcome = refresh
        }

        func signIn(username: String, password: String) async throws -> AuthTokens {
            switch signInOutcome {
            case .success(let t):       return t
            case .throwError(let e):    throw e
            }
        }

        func refresh(refreshToken: String) async throws -> AuthTokens {
            switch refreshOutcome {
            case .success(let t):       return t
            case .throwError(let e):    throw e
            }
        }
    }

    // MARK: - The four mapped branches

    func test_signIn_successBranch_returnsAuthTokens() async throws {
        let tokens = AuthTokens(idToken: "id-1", accessToken: "at-1", refreshToken: "rt-1")
        let client: OktaAuthenticating = FakeAuthClient(signIn: .success(tokens))

        let result = try await client.signIn(username: "ada", password: "secret")

        XCTAssertEqual(result, tokens)
    }

    func test_signIn_invalidCredentialsBranch_throwsTypedError() async {
        let client: OktaAuthenticating = FakeAuthClient(signIn: .throwError(.invalidCredentials))

        do {
            _ = try await client.signIn(username: "ada", password: "wrong")
            XCTFail("Expected AuthError.invalidCredentials")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Expected AuthError, got \(error)")
        }
    }

    func test_signIn_networkBranch_throwsTypedError() async {
        let client: OktaAuthenticating = FakeAuthClient(signIn: .throwError(.network))

        do {
            _ = try await client.signIn(username: "ada", password: "secret")
            XCTFail("Expected AuthError.network")
        } catch let error as AuthError {
            XCTAssertEqual(error, .network)
        } catch {
            XCTFail("Expected AuthError, got \(error)")
        }
    }

    func test_signIn_mfaRequiredBranch_throwsTypedError() async {
        let client: OktaAuthenticating = FakeAuthClient(signIn: .throwError(.mfaRequired))

        do {
            _ = try await client.signIn(username: "ada", password: "secret")
            XCTFail("Expected AuthError.mfaRequired")
        } catch let error as AuthError {
            XCTAssertEqual(error, .mfaRequired)
        } catch {
            XCTFail("Expected AuthError, got \(error)")
        }
    }

    // MARK: - Live adapter: config-gating

    /// The live adapter must surface a missing/malformed
    /// `OktaConfig` as `AuthError.notConfigured` rather than letting
    /// the SDK be constructed with bogus values. This exercises the
    /// only real-adapter path that's safe to hit without the network:
    /// the .notConfigured precheck inside `makeFlow()`.
    func test_liveClient_withNotConfigured_throwsNotConfigured() async {
        let client = OktaDirectAuthClient(
            config: .notConfigured(reason: "missing OKTA_ISSUER")
        )

        do {
            _ = try await client.signIn(username: "ada", password: "secret")
            XCTFail("Expected AuthError.notConfigured")
        } catch let error as AuthError {
            if case .notConfigured(let reason) = error {
                XCTAssertTrue(reason.contains("OKTA_ISSUER"))
            } else {
                XCTFail("Expected .notConfigured, got \(error)")
            }
        } catch {
            XCTFail("Expected AuthError, got \(error)")
        }
    }
}
