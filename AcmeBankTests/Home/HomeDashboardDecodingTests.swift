import XCTest
@testable import AcmeBank

/// Decoding guard for the `GET /v1/home` contract.
///
/// The deployed BFF serialises snake_case fields (`first_name`,
/// `masked_number`, `posted_date`, `currency_code`, `recent_transactions`,
/// `available_balance`, …). An earlier `HomeDashboard` model expected
/// different names (`display_name`, `account_number`, `account_type`,
/// `currency`, `date`) and the `checking` enum spelling, so it threw on
/// every real response — surfacing as "Couldn't reach Acme Bank" on the
/// Home screen. This decodes a payload shaped exactly like the deployed
/// BFF (per its OpenAPI `/v3/api-docs`) with the SAME decoder
/// configuration `BFFHomeRepository` uses, and fails against any model
/// that drifts from that contract again.
final class HomeDashboardDecodingTests: XCTestCase {

    /// Mirrors the decoder configured in `BFFHomeRepository.fetchHome()`.
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func amount(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    func testDecodesDeployedBFFHomePayload() throws {
        let json = Data("""
        {
          "customer": {
            "id": "cust-1001",
            "first_name": "Demo",
            "last_name": "User",
            "email": "demo.user@sisystems.com",
            "phone_number": "+1-416-555-0142"
          },
          "accounts": [
            { "id": "acct-1", "name": "Unlimited Chequing", "masked_number": "4821", "balance": 4287.52, "available_balance": 4287.52, "type": "chequing", "currency_code": "USD" },
            { "id": "acct-2", "name": "High-Interest Savings", "masked_number": "9203", "balance": 18940.00, "available_balance": 18940.00, "type": "savings", "currency_code": "USD" }
          ],
          "recent_transactions": [
            { "id": "txn-9", "account_id": "acct-1", "description": "Coffee Bar", "amount": -4.75, "posted_date": "2026-06-07T13:11:00Z", "category": "dining", "merchant_name": "Coffee Bar" }
          ]
        }
        """.utf8)

        let home = try makeDecoder().decode(HomeDashboard.self, from: json)

        // Customer: first/last name + derived display name.
        XCTAssertEqual(home.customer.firstName, "Demo")
        XCTAssertEqual(home.customer.lastName, "User")
        XCTAssertEqual(home.customer.displayName, "Demo User")
        XCTAssertEqual(home.customer.email, "demo.user@sisystems.com")
        XCTAssertEqual(home.customer.phoneNumber, "+1-416-555-0142")

        // Accounts: BFF field names + enum spelling.
        XCTAssertEqual(home.accounts.count, 2)
        let chequing = home.accounts[0]
        XCTAssertEqual(chequing.name, "Unlimited Chequing")
        XCTAssertEqual(chequing.maskedNumber, "4821")
        XCTAssertEqual(chequing.type, .chequing)
        XCTAssertEqual(chequing.currencyCode, "USD")
        XCTAssertEqual(amount(chequing.balance), 4287.52, accuracy: 0.001)
        XCTAssertEqual(amount(chequing.availableBalance), 4287.52, accuracy: 0.001)
        XCTAssertEqual(home.accounts[1].type, .savings)

        // Transactions: account_id, posted_date, nullable category/merchant.
        XCTAssertEqual(home.recentTransactions.count, 1)
        let tx = home.recentTransactions[0]
        XCTAssertEqual(tx.accountId, "acct-1")
        XCTAssertEqual(tx.description, "Coffee Bar")
        XCTAssertEqual(amount(tx.amount), -4.75, accuracy: 0.001)
        XCTAssertEqual(tx.category, "dining")
        XCTAssertEqual(tx.merchantName, "Coffee Bar")
        XCTAssertEqual(tx.postedDate, ISO8601DateFormatter().date(from: "2026-06-07T13:11:00Z"))
    }

    /// The BFF emits UPPERCASE account-type strings (`CHEQUING`, …).
    /// Account-type decode is case-insensitive, so both the lowercase
    /// spelling and the wire UPPERCASE spelling resolve to the same case
    /// (and never silently fall back to `.unknown`, which would render
    /// the generic icon for every row).
    func testAccountTypeDecodeIsCaseInsensitive() throws {
        let json = Data("""
        {
          "customer": { "id": "c", "first_name": "A", "last_name": "B", "email": "a@b.com" },
          "accounts": [
            { "id": "a1", "name": "Lower", "masked_number": "1111", "balance": 0, "available_balance": 0, "type": "chequing", "currency_code": "USD" },
            { "id": "a2", "name": "Upper", "masked_number": "2222", "balance": 0, "available_balance": 0, "type": "CHEQUING", "currency_code": "USD" },
            { "id": "a3", "name": "UpperCredit", "masked_number": "3333", "balance": 0, "available_balance": 0, "type": "CREDIT", "currency_code": "USD" }
          ],
          "recent_transactions": []
        }
        """.utf8)
        let home = try makeDecoder().decode(HomeDashboard.self, from: json)
        XCTAssertEqual(home.accounts[0].type, .chequing)   // "chequing"
        XCTAssertEqual(home.accounts[1].type, .chequing)   // "CHEQUING"
        XCTAssertEqual(home.accounts[2].type, .credit)     // "CREDIT"
    }

    /// `AccountType.displayName` is the title-cased label used in the
    /// Account row subtitle; `.credit` reads "Credit Card" and `.unknown`
    /// reads "Account".
    func testAccountTypeDisplayNames() {
        XCTAssertEqual(AccountType.chequing.displayName, "Chequing")
        XCTAssertEqual(AccountType.savings.displayName, "Savings")
        XCTAssertEqual(AccountType.credit.displayName, "Credit Card")
        XCTAssertEqual(AccountType.investment.displayName, "Investment")
        XCTAssertEqual(AccountType.unknown.displayName, "Account")
    }

    /// Unknown account types fall back to `.unknown` rather than failing
    /// the whole decode (forward-compatibility as the BFF adds types).
    func testUnknownAccountTypeFallsBackToUnknown() throws {
        let json = Data("""
        {
          "customer": { "id": "c", "first_name": "A", "last_name": "B", "email": "a@b.com" },
          "accounts": [ { "id": "x", "name": "Mystery", "masked_number": "0000", "balance": 0, "available_balance": 0, "type": "crypto_wallet", "currency_code": "USD" } ],
          "recent_transactions": []
        }
        """.utf8)
        let home = try makeDecoder().decode(HomeDashboard.self, from: json)
        XCTAssertEqual(home.accounts.first?.type, .unknown)
    }

    /// Nullable fields (`phone_number`, `category`, `merchant_name`) decode
    /// to nil when the BFF omits them.
    func testNullableFieldsDecodeToNilWhenOmitted() throws {
        let json = Data("""
        {
          "customer": { "id": "c", "first_name": "A", "last_name": "B", "email": "a@b.com" },
          "accounts": [],
          "recent_transactions": [ { "id": "t", "account_id": "a", "description": "X", "amount": 1, "posted_date": "2026-06-07T13:11:00Z" } ]
        }
        """.utf8)
        let home = try makeDecoder().decode(HomeDashboard.self, from: json)
        XCTAssertNil(home.customer.phoneNumber)
        XCTAssertNil(home.recentTransactions.first?.category)
        XCTAssertNil(home.recentTransactions.first?.merchantName)
    }
}
