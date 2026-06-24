import Foundation

/// Top-level response from `GET /v1/home`.
///
/// All value types; Codable via `.convertFromSnakeCase` so field names
/// like `account_number` and `display_name` decode automatically from
/// the BFF's snake_case JSON without custom `CodingKeys`.
public struct HomeDashboard: Equatable, Codable {
    public let customer: Customer
    public let accounts: [Account]
    public let recentTransactions: [Transaction]

    public init(customer: Customer, accounts: [Account], recentTransactions: [Transaction]) {
        self.customer = customer
        self.accounts = accounts
        self.recentTransactions = recentTransactions
    }
}

/// Customer profile included in the home response.
public struct Customer: Equatable, Codable {
    public let id: String
    public let displayName: String
    public let email: String

    public init(id: String, displayName: String, email: String) {
        self.id = id
        self.displayName = displayName
        self.email = email
    }
}

/// A single bank account belonging to the customer.
public struct Account: Equatable, Codable {
    public let id: String
    public let accountNumber: String
    public let accountType: AccountType
    public let balance: Decimal
    public let currency: String

    public init(
        id: String,
        accountNumber: String,
        accountType: AccountType,
        balance: Decimal,
        currency: String
    ) {
        self.id = id
        self.accountNumber = accountNumber
        self.accountType = accountType
        self.balance = balance
        self.currency = currency
    }
}

/// Account type as returned by the BFF.
///
/// `RawRepresentable` with a `String` raw value so JSON strings map
/// directly. The failable `init(rawValue:)` falls back to `.unknown`
/// for unrecognised server values — forward-compatible as the BFF adds
/// new account types.
public enum AccountType: String, Equatable, Codable {
    case checking
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
public struct Transaction: Equatable, Codable {
    public let id: String
    public let accountId: String
    public let description: String
    public let amount: Decimal
    public let currency: String
    public let date: Date

    public init(
        id: String,
        accountId: String,
        description: String,
        amount: Decimal,
        currency: String,
        date: Date
    ) {
        self.id = id
        self.accountId = accountId
        self.description = description
        self.amount = amount
        self.currency = currency
        self.date = date
    }
}
