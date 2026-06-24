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
/// customer tier (e.g. `"RETAIL"`, `"PREMIER"`). It is omitted from
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
/// directly. The cases mirror the BFF OpenAPI contract exactly —
/// `segment: enum: [RETAIL, PREMIER, PRIVATE, BUSINESS]` — so every tier
/// the backend can emit renders a badge.
///
/// NOTE: an earlier version used a non-existent `STANDARD` case and
/// omitted `RETAIL` / `PRIVATE` / `BUSINESS`, so every `RETAIL` customer
/// (the majority of the demo set — Bankuser One, Norm User) fell through
/// to `.unknown` and showed no badge, while only the lone `PREMIER`
/// customer rendered one. The failable `init(from:)` still falls back to
/// `.unknown` for any value outside the contract (forward-compatible if
/// the BFF adds a new tier), and `.unknown` is intentionally badge-less so
/// an unvetted future value never renders blank or nonsensical text.
public enum CustomerSegment: String, Equatable, Codable {
    case retail         = "RETAIL"
    case premier        = "PREMIER"
    case privateBanking = "PRIVATE"
    case business       = "BUSINESS"
    case unknown

    /// Failable init that falls back to `.unknown` for unrecognised
    /// raw values rather than failing the entire Codable decode.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = CustomerSegment(rawValue: raw) ?? .unknown
    }

    /// Human-readable display string for badge rendering.
    /// Returns `nil` for `.unknown` so callers don't render a badge for
    /// unrecognised or empty segment values.
    public var badgeText: String? {
        switch self {
        case .retail:         return "RETAIL"
        case .premier:        return "PREMIER"
        case .privateBanking: return "PRIVATE"
        case .business:       return "BUSINESS"
        case .unknown:        return nil
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
///
/// Decoding is **case-insensitive**: the wire value is lowercased before
/// matching, so both `"chequing"` and `"CHEQUING"` resolve to
/// `.chequing`. The mock backend / BFF emit UPPERCASE type strings
/// (`CHEQUING | SAVINGS | CREDIT | INVESTMENT`); without normalisation
/// every row would fall back to `.unknown` and render the generic
/// dollar-sign icon instead of the per-type icon.
public enum AccountType: String, Equatable, Codable {
    case chequing
    case savings
    case credit
    case investment
    case unknown

    /// Failable init that lowercases the wire value before matching and
    /// falls back to `.unknown` for unrecognised raw values rather than
    /// failing the entire Codable decode. The lowercasing makes the
    /// decode survive the BFF's UPPERCASE convention.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = AccountType(rawValue: raw.lowercased()) ?? .unknown
    }

    /// Title-cased, human-readable label for the account type, used in
    /// the Account row subtitle. `.credit` reads "Credit Card" and
    /// `.unknown` reads "Account" (a neutral fallback) per the Home
    /// story.
    public var displayName: String {
        switch self {
        case .chequing:   return "Chequing"
        case .savings:    return "Savings"
        case .credit:     return "Credit Card"
        case .investment: return "Investment"
        case .unknown:    return "Account"
        }
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

// MARK: - Derived currency

public extension HomeDashboard {
    /// Resolve the currency a transaction's amount should render in.
    ///
    /// The BFF sends no per-transaction currency, so a transaction
    /// inherits the currency of its **owning account** (matched by
    /// `accountId`). Falls back to the first account's currency when the
    /// owning account isn't in the returned set, and finally to `"USD"`
    /// only when there are no accounts at all — in which case there are no
    /// transactions to render either. Keeps the Recent Transactions list
    /// in the same currency as the Accounts list, so a CAD dataset no
    /// longer renders transaction amounts as `US$`.
    func displayCurrency(for transaction: Transaction) -> String {
        accounts.first(where: { $0.id == transaction.accountId })?.currencyCode
            ?? accounts.first?.currencyCode
            ?? "USD"
    }
}
