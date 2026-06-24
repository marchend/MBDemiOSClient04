import XCTest
@testable import AcmeBank

/// Unit coverage for `SessionRestorer`.
///
/// Fakes \u2014 NOT the real Okta SDK \u2014 drive every test, per the prior
/// lesson "Put the IdP SDK behind a NEUTRAL protocol seam". The
/// restorer's contract is "ask the auth seam for a refresh, decode
/// the ID token, project into a `UserSession`", and that's exactly
/// what we assert.
final class SessionRestorerTests: XCTestCase {

    // MARK: - Fakes

    /// Scriptable `OktaAuthenticating`. Refresh is the only method
    /// exercised in this suite; `signIn` is a no-op throw.
    private final class FakeAuthClient: OktaAuthenticating {
        enum RefreshOutcome {
            case success(AuthTokens)
            case throwError(AuthError)
        }

        var refreshOutcome: RefreshOutcome
        private(set) var refreshCallCount = 0
        private(set) var lastRefreshToken: String?

        init(refreshOutcome: RefreshOutcome) {
            self.refreshOutcome = refreshOutcome
        }

        func signIn(username: String, password: String) async throws -> AuthTokens {
            throw AuthError.network
        }

        func refresh(refreshToken: String) async throws -> AuthTokens {
            refreshCallCount += 1
            lastRefreshToken = refreshToken
            switch refreshOutcome {
            case .success(let t):   return t
            case .throwError(let e): throw e
            }
        }
    }

    // MARK: - JWT helpers

    /// Build a `header.payload.signature` JWT with the supplied JSON
    /// as the middle (payload) segment. Mirrors the helper in
    /// `IDTokenDecoderTests` so the same well-formed token shape is
    /// shared.
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

    private static var validIDToken: String {
        makeJWT(payloadJSON: """
        {"sub":"user-123","name":"Ada Lovelace","email":"ada@acmebank.com","auth_time":1700000000}
        """)
    }

    // MARK: - Happy path

    func test_restore_success_returnsUserSessionPopulatedFromIDTokenClaims() async throws {
        let auth = FakeAuthClient(refreshOutcome: .success(
            AuthTokens(
                idToken: Self.validIDToken,
                accessToken: "fresh-access",
                refreshToken: "fresh-refresh"
            )
        ))

        let session = try await SessionRestorer.restore(
            refreshToken: "old-refresh",
            authClient: auth,
            deviceName: "TestDevice"
        )

        XCTAssertEqual(auth.refreshCallCount, 1)
        XCTAssertEqual(auth.lastRefreshToken, "old-refresh",
                       "The restorer must pass the supplied refresh token to the auth seam unchanged")
        XCTAssertEqual(session.userId, "user-123")
        XCTAssertEqual(session.displayName, "Ada Lovelace")
        XCTAssertEqual(session.email, "ada@acmebank.com")
        XCTAssertEqual(session.accessToken, "fresh-access",
                       "UserSession must carry the freshly minted access token, not the old one")
        XCTAssertEqual(session.authTimestamp, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(session.deviceName, "TestDevice")
    }

    func test_restore_success_appliesDisplayNameFallback_whenNameClaimAbsent() async throws {
        // Payload missing `name` \u2014 fallback chain prefers `email`.
        let token = Self.makeJWT(payloadJSON: """
        {"sub":"user-x","email":"only-email@acmebank.com"}
        """)
        let auth = FakeAuthClient(refreshOutcome: .success(
            AuthTokens(idToken: token, accessToken: "at", refreshToken: nil)
        ))

        let session = try await SessionRestorer.restore(
            refreshToken: "rt",
            authClient: auth,
            deviceName: "Dev"
        )

        XCTAssertEqual(session.displayName, "only-email@acmebank.com",
                       "displayName must fall back to email when name claim is absent")
    }

    func test_restore_success_appliesSubFallback_whenNameAndEmailAbsent() async throws {
        let token = Self.makeJWT(payloadJSON: """
        {"sub":"sub-only-user"}
        """)
        let auth = FakeAuthClient(refreshOutcome: .success(
            AuthTokens(idToken: token, accessToken: "at", refreshToken: nil)
        ))

        let session = try await SessionRestorer.restore(
            refreshToken: "rt",
            authClient: auth,
            deviceName: "Dev"
        )

        XCTAssertEqual(session.displayName, "sub-only-user",
                       "displayName must fall back to sub when both name and email are absent")
        XCTAssertEqual(session.email, "",
                       "email must be the empty string when the claim is absent")
    }

    // MARK: - Failure paths

    func test_restore_authClientThrowsNetwork_propagatesUnchanged() async {
        let auth = FakeAuthClient(refreshOutcome: .throwError(.network))

        do {
            _ = try await SessionRestorer.restore(
                refreshToken: "rt",
                authClient: auth,
                deviceName: "Dev"
            )
            XCTFail("Expected SessionRestorer to rethrow the auth client's error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .network,
                           "Auth-client errors must propagate unchanged so the caller can dispatch on type")
        } catch {
            XCTFail("Expected AuthError, got \(error)")
        }
    }

    func test_restore_authClientThrowsInvalidCredentials_propagatesUnchanged() async {
        // A stale refresh token can manifest as an IdP-side
        // .invalidCredentials response \u2014 the contract is to propagate
        // it so the caller's "any throw \u2192 clear stale token" arm fires.
        let auth = FakeAuthClient(refreshOutcome: .throwError(.invalidCredentials))

        do {
            _ = try await SessionRestorer.restore(
                refreshToken: "rt",
                authClient: auth,
                deviceName: "Dev"
            )
            XCTFail("Expected SessionRestorer to rethrow the auth client's error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .invalidCredentials)
        } catch {
            XCTFail("Expected AuthError, got \(error)")
        }
    }

    func test_restore_refreshResponseMissingIDToken_throwsMalformedToken() async {
        // The IdP returned a 200 with NO `id_token`. Without claims we
        // can't build a UserSession; the restorer must surface this
        // as `.malformedToken` so the caller treats it like any other
        // failure (clear the stale refresh and fall through to Login).
        let auth = FakeAuthClient(refreshOutcome: .success(
            AuthTokens(idToken: nil, accessToken: "at", refreshToken: nil)
        ))

        do {
            _ = try await SessionRestorer.restore(
                refreshToken: "rt",
                authClient: auth,
                deviceName: "Dev"
            )
            XCTFail("Expected SessionRestorer to throw when the refresh response omits the ID token")
        } catch let error as AuthError {
            XCTAssertEqual(error, .malformedToken)
        } catch {
            XCTFail("Expected AuthError.malformedToken, got \(error)")
        }
    }

    func test_restore_refreshResponseHasUnparsableIDToken_throwsMalformedToken() async {
        // A non-JWT string fails IDTokenDecoder's structural check;
        // that throw must also surface as `.malformedToken` (it
        // already does \u2014 IDTokenDecoder throws AuthError.malformedToken
        // \u2014 we just verify the restorer doesn't swallow or rewrap it).
        let auth = FakeAuthClient(refreshOutcome: .success(
            AuthTokens(idToken: "not.a.jwt", accessToken: "at", refreshToken: nil)
        ))

        do {
            _ = try await SessionRestorer.restore(
                refreshToken: "rt",
                authClient: auth,
                deviceName: "Dev"
            )
            XCTFail("Expected SessionRestorer to throw when the ID token is unparsable")
        } catch let error as AuthError {
            XCTAssertEqual(error, .malformedToken)
        } catch {
            XCTFail("Expected AuthError.malformedToken, got \(error)")
        }
    }
}
