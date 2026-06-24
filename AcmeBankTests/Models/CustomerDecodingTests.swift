import XCTest
@testable import AcmeBank

/// Unit tests verifying that the `Customer.segment` field decodes
/// correctly under all three JSON representations:
///   1. `"segment": "PREMIER"` — field present with a known string value.
///   2. `"segment"` key entirely omitted — optional field defaults to `nil`.
///   3. `"segment": null` — explicit JSON null maps to Swift `nil`.
///   4. `"segment": "FUTURE_TIER"` — unknown value falls back to `.unknown`.
///
/// Uses the same `.convertFromSnakeCase` + `.iso8601` decoder that
/// `BFFHomeRepository` uses in production, exercised via the full
/// `HomeDashboard` wrapper so the test validates real end-to-end
/// decode behaviour.
final class CustomerDecodingTests: XCTestCase {

    // MARK: - Decoder

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Minimal wrapper JSON helpers

    /// Wraps a customer JSON fragment in a minimal `HomeDashboard` envelope
    /// so the full `Codable` path is exercised.
    private func dashboardJSON(customerFragment: String) -> Data {
        Data("""
        {
          "customer": \(customerFragment),
          "accounts": [],
          "recent_transactions": []
        }
        """.utf8)
    }

    // MARK: - Test cases

    /// Field present with a known string value — `segment` must decode
    /// to the matching `CustomerSegment` case.
    func test_segment_decodesStringValue() throws {
        let json = dashboardJSON(customerFragment: """
        {
          "id": "cust-001",
          "first_name": "Ada",
          "last_name": "Lovelace",
          "email": "ada@acmebank.com",
          "segment": "PREMIER"
        }
        """)

        let home = try makeDecoder().decode(HomeDashboard.self, from: json)

        XCTAssertEqual(home.customer.segment, .premier,
                       "segment must decode to .premier for JSON value \"PREMIER\"")
    }

    /// Key entirely absent from JSON — optional `segment` must be `nil`
    /// and the decode must not throw.
    func test_segment_isNilWhenKeyOmitted() throws {
        let json = dashboardJSON(customerFragment: """
        {
          "id": "cust-002",
          "first_name": "Grace",
          "last_name": "Hopper",
          "email": "grace@acmebank.com"
        }
        """)

        let home = try makeDecoder().decode(HomeDashboard.self, from: json)

        XCTAssertNil(home.customer.segment,
                     "segment must be nil when the JSON key is omitted")
    }

    /// Key present with an explicit JSON `null` value — optional `segment`
    /// must be `nil` and the decode must not throw.
    func test_segment_isNilWhenExplicitNull() throws {
        let json = dashboardJSON(customerFragment: """
        {
          "id": "cust-003",
          "first_name": "Charles",
          "last_name": "Babbage",
          "email": "charles@acmebank.com",
          "segment": null
        }
        """)

        let home = try makeDecoder().decode(HomeDashboard.self, from: json)

        XCTAssertNil(home.customer.segment,
                     "segment must be nil when the JSON value is null")
    }

    /// Unknown future tier string — must decode to `.unknown` rather than
    /// failing the whole decode, preserving forward-compatibility.
    func test_segment_fallsBackToUnknownForUnrecognisedValue() throws {
        let json = dashboardJSON(customerFragment: """
        {
          "id": "cust-005",
          "first_name": "Margaret",
          "last_name": "Hamilton",
          "email": "margaret@acmebank.com",
          "segment": "PLATINUM_ELITE"
        }
        """)

        let home = try makeDecoder().decode(HomeDashboard.self, from: json)

        XCTAssertEqual(home.customer.segment, .unknown,
                       "Unrecognised segment values must fall back to .unknown rather than failing")
    }

    // MARK: - Existing nullable fields unchanged

    /// Regression: the addition of `segment` must not break decoding of
    /// other optional fields (`phone_number`).
    func test_existingNullableFields_unaffectedBySegmentAddition() throws {
        let json = dashboardJSON(customerFragment: """
        {
          "id": "cust-004",
          "first_name": "Alan",
          "last_name": "Turing",
          "email": "alan@acmebank.com",
          "phone_number": "+1-416-555-0300",
          "segment": "STANDARD"
        }
        """)

        let home = try makeDecoder().decode(HomeDashboard.self, from: json)
        let customer = home.customer

        XCTAssertEqual(customer.phoneNumber, "+1-416-555-0300")
        XCTAssertEqual(customer.segment, .standard)
        XCTAssertEqual(customer.displayName, "Alan Turing")
    }
}
