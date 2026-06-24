import XCTest
@testable import AcmeBank

final class IDTokenDecoderTests: XCTestCase {
    // MARK: - Happy path

    /// Build a synthetic JWT with known claims and assert the decoder
    /// returns them verbatim. We build the JWT in-test rather than
    /// hard-coding a long base64url string so a future field rename
    /// doesn't require recomputing the encoding by hand.
    func test_decode_validJWT_returnsClaims() throws {
        let payloadJSON = """
        {"sub":"user-123","name":"Ada Lovelace","email":"ada@acmebank.com","auth_time":1700000000}
        """
        let jwt = Self.makeJWT(payloadJSON: payloadJSON)

        let claims = try IDTokenDecoder.decode(jwt)

        XCTAssertEqual(claims.sub, "user-123")
        XCTAssertEqual(claims.name, "Ada Lovelace")
        XCTAssertEqual(claims.email, "ada@acmebank.com")
        XCTAssertEqual(claims.auth_time, Date(timeIntervalSince1970: 1_700_000_000))
    }

    /// `auth_time` is optional per the spec. When absent the decoder
    /// must still succeed and leave the field nil.
    func test_decode_jwtWithoutAuthTime_succeedsWithNilAuthTime() throws {
        let payloadJSON = """
        {"sub":"u","name":"n","email":"e@e.com"}
        """
        let jwt = Self.makeJWT(payloadJSON: payloadJSON)

        let claims = try IDTokenDecoder.decode(jwt)

        XCTAssertEqual(claims.sub, "u")
        XCTAssertNil(claims.auth_time)
    }

    /// `name` and `email` are also optional (they require the
    /// `profile` / `email` scopes and a populated user profile). A JWT
    /// with neither must still decode successfully so a partial-scope
    /// tenant config doesn't masquerade as a malformed-token error.
    func test_decode_jwtWithoutNameOrEmail_succeedsWithNilFields() throws {
        let payloadJSON = """
        {"sub":"u"}
        """
        let jwt = Self.makeJWT(payloadJSON: payloadJSON)

        let claims = try IDTokenDecoder.decode(jwt)

        XCTAssertEqual(claims.sub, "u")
        XCTAssertNil(claims.name)
        XCTAssertNil(claims.email)
        XCTAssertNil(claims.auth_time)
    }

    // MARK: - Malformed inputs

    func test_decode_garbage_throwsMalformedToken() {
        XCTAssertThrowsError(try IDTokenDecoder.decode("not.a.jwt")) { error in
            XCTAssertEqual(error as? AuthError, .malformedToken)
        }
    }

    func test_decode_singleSegment_throwsMalformedToken() {
        XCTAssertThrowsError(try IDTokenDecoder.decode("onlyonesegment")) { error in
            XCTAssertEqual(error as? AuthError, .malformedToken)
        }
    }

    func test_decode_emptyString_throwsMalformedToken() {
        XCTAssertThrowsError(try IDTokenDecoder.decode("")) { error in
            XCTAssertEqual(error as? AuthError, .malformedToken)
        }
    }

    func test_decode_jwtWithMissingRequiredClaim_throwsMalformedToken() {
        // Missing `sub` — the ONLY claim required by OIDC Core and
        // the only non-optional field in `IDTokenClaims`. JSONDecoder
        // fails and we map to .malformedToken. (`name` / `email` are
        // optional and covered by the success-case test above.)
        let payloadJSON = """
        {"name":"n","email":"e@e.com"}
        """
        let jwt = Self.makeJWT(payloadJSON: payloadJSON)

        XCTAssertThrowsError(try IDTokenDecoder.decode(jwt)) { error in
            XCTAssertEqual(error as? AuthError, .malformedToken)
        }
    }

    // MARK: - JWT helper

    /// Build a `header.payload.signature` JWT string where the
    /// payload is a base64url-encoded copy of the supplied JSON. The
    /// header and signature are placeholder strings; the decoder
    /// only reads the middle segment.
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
}
