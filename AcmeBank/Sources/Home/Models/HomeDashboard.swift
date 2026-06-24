import Foundation

/// Top-level response from `GET /v1/home`.
///
/// All value types; Codable via `.convertFromSnakeCase` so the BFF's
/// snake_case field names (`recent_transactions`, `masked_number`,
/// `posted_date`, …) decode automatically into these camelCase
/// properties without custom `CodingKeys`.
public struct HomeDashboard: Equatable, Codable {
    public let customer: Customer
    public let accounts: [Account]
    public let recentTransactions: [Transaction]   // recent_transactions

    public init(customer: Customer, accounts: [Account], recentTransactions: [Transaction]) {
        self.customer = customer
        self.accounts = accounts
        self.recentTransactions = recentTransactions
    }
}

/// Customer profile included in the home response.
///
/// The BFF sends `first_name` + `last_name` separately (it does not
/// send a pre-combined display name), so `displayName` is derived here.
///
/// The optional `segment` field (`"segment"` in JSON) identifies the
/// customer tier (e.g. `"PREMIER"`, `"STANDARD"`). It is omitted from
/// the BFF response for customers with no assigned segment, so the
/// field is `Optional<CustomerSegment>`. `.convertFromSnakeCase` maps
/// the JSON key `"segment"` directly to `segment` (no custom
/// `CodingKeys` required). Unknown tier strings fall back to
/// `CustomerSegment.unknown` via a custom `init(from:)`, preserving
/// forward-compatibility as the BFF adds new tiers.
public struct Customer: Equatable, Codable {
    public let id: String
    public let firstName: String       // first_name
    public let lastName: String        // last_name
    public let email: String
    public let phoneNumber: String?    // phone_number (nullable)
    public let segment: CustomerSegment?  // customer tier, e.g. .premier (nullable)

    public init(
        id: String,
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String? = nil,
        segment: CustomerSegment? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.segment = segment
    }

    /// Full name for display, derived from `firstName` + `lastName`.
    /// Falls back to `email` if both name parts are blank.
    public var displayName: String {
        let full = "\(firstName) \(lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? email : full
    }
}

/// Customer segment / tier as returned by the BFF (`segment` field).
///
/// `RawRepresentable` with a `String` raw value so JSON strings map
/// directly. The failable `init(from:)` falls back to `.unknown` for
/// unrecognised server values — forward-compatible as the BFF adds new
/// segment tiers. Raw values use the BFF's uppercase convention.
///
/// Only `.premier` and `.standard` have a visible badge; `.unknown`
/// is intentionally hidden so unvetted future values don't render
/// blank or nonsensical text on the card.
public enum CustomerSegment: String, Equatable, Codable {
    case premier  = "PREMIER"
    case standard = "STANDARD"
    case unknown

    /// Failable init that falls back to `.unknown` for unrecognised
    /// raw values rather than failing the entire Codable decode.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = CustomerSegment(rawValue: raw) ?? .unknown
    }

    /// Human-readable display string for badge rendering.
    /// Returns `nil` for `.unknown` so callers can choose not to
    /// render a badge for unrecognised or empty segment values.
    public var badgeText: String? {
        switch self {
        case .premier:  return "PREMIER"
        case .standard: return "STANDARD"
        case .unknown:  return nil
        }
    }
}

/// A single bank account belonging to the customer.
public struct Account: Equatable, Codable {
    public let id: String
    public let name: String                // friendly name, e.g. "Unlimited Chequing"
    public let maskedNumber: String        // masked_number, e.g. "4821"
    public let balance: Decimal
    public let availableBalance: Decimal   // available_balance
    public let type: AccountType
    public let currencyCode: String        // currency_code

    public init(
        id: String,
        name: String,
        maskedNumber: String,
        balance: Decimal,
        availableBalance: Decimal,
        type: AccountType,
        currencyCode: String
    ) {
        self.id = id
        self.name = name
        self.maskedNumber = maskedNumber
        self.balance = balance
        self.availableBalance = availableBalance
        self.type = type
        self.currencyCode = currencyCode
    }
}

/// Account type as returned by the BFF (`type` field).
///
/// `RawRepresentable` with a `String` raw value so JSON strings map
/// directly. The failable `init(from:)` falls back to `.unknown` for
/// unrecognised server values — forward-compatible as the BFF adds new
/// account types. Note the raw value is `chequing` (CA spelling), to
/// match the BFF enum `[chequing, savings, credit, investment]`.
public enum AccountType: String, Equatable, Codable {
    case chequing
    case savings
    case credit
    case investment
    case unknown

    /// Failable init that falls back to `.unknown` for unrecognised
    /// raw values rather than failing the entire Codable decode.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = AccountType(rawValue: raw) ?? .unknown
    }
}

/// A single transaction belonging to an account.
///
/// The BFF does not send a per-transaction currency; amounts render in
/// the owning account's currency (USD across the demo dataset).
public struct Transaction: Equatable, Codable {
    public let id: String
    public let accountId: String           // account_id
    public let description: String
    public let amount: Decimal
    public let postedDate: Date            // posted_date (iso8601)
    public let category: String?           // nullable
    public let merchantName: String?       // merchant_name (nullable)

    public init(
        id: String,
        accountId: String,
        description: String,
        amount: Decimal,
        postedDate: Date,
        category: String? = nil,
        merchantName: String? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.description = description
        self.amount = amount
        self.postedDate = postedDate
        self.category = category
        self.merchantName = merchantName
    }
}
