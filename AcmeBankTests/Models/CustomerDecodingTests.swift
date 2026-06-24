import XCTest
@testable import AcmeBank

/// Unit tests verifying that the `Customer.segment` field decodes
/// correctly under all three JSON representations:
///   1. `"segment": "PREMIER"` — field present with a string value.
///   2. `"segment"` key entirely omitted — optional field defaults to `nil`.
///   3. `"segment": null` — explicit JSON null maps to Swift `nil`.
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

    /// Field present with a non-null string value — `segment` must equal
    /// the decoded string.
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

        XCTAssertEqual(home.customer.segment, "PREMIER",
                       "segment must equal the decoded JSON string")
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
        XCTAssertEqual(customer.segment, "STANDARD")
        XCTAssertEqual(customer.displayName, "Alan Turing")
    }
}
