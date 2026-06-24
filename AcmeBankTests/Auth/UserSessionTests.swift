import XCTest
@testable import AcmeBank

final class UserSessionTests: XCTestCase {
    /// Round-trip through `JSONEncoder` / `JSONDecoder` proves the
    /// `Codable` synthesis covers every field and that `Date` is
    /// preserved with sufficient fidelity for the Keychain blob path
    /// PR 3 / PR 4 will use.
    func test_userSession_codableRoundTrip_preservesAllFields() throws {
        let original = UserSession(
            userId: "00uabc123def456GHI",
            displayName: "Ada Lovelace",
            email: "ada@acmebank.com",
            accessToken: "eyJraWQiOiJ4eC1hYy10ZXN0In0.payload.sig",
            // Use a date with NO sub-second component so the
            // .secondsSince1970-friendly default JSON encoding doesn't
            // suffer floating-point drift on round-trip.
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName: "iPhone 16 Simulator"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserSession.self, from: data)

        XCTAssertEqual(decoded, original)
        // Spot-check individual fields for clearer failure output if
        // synthesis changes shape later.
        XCTAssertEqual(decoded.userId, original.userId)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.email, original.email)
        XCTAssertEqual(decoded.accessToken, original.accessToken)
        XCTAssertEqual(decoded.authTimestamp, original.authTimestamp)
        XCTAssertEqual(decoded.deviceName, original.deviceName)
    }

    /// `UserSession` carries the access token but NOT a refresh
    /// token: refresh tokens live in the keychain under their own
    /// service. This guards against a future field-list edit that
    /// would leak a refresh token into a logged or otherwise
    /// non-secret context.
    func test_userSession_hasNoRefreshTokenField() throws {
        let session = UserSession(
            userId: "u1",
            displayName: "Test",
            email: "t@acme.com",
            accessToken: "at",
            authTimestamp: Date(timeIntervalSince1970: 0),
            deviceName: "device"
        )
        let data = try JSONEncoder().encode(session)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(json["refreshToken"], "UserSession must not serialize a refreshToken field")
        XCTAssertNil(json["refresh_token"], "UserSession must not serialize a refresh_token field")
    }
}
