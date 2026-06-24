import Foundation

/// Configurable in-memory `HomeRepositoryProtocol` for tests and
/// SwiftUI previews.
///
/// Set `shouldThrow` to a `HomeError` to simulate failure paths.
/// When `shouldThrow` is `nil` the stub returns the hard-coded
/// `bankuser.one` fixture (a representative dashboard with 4 accounts
/// and 3 transactions).
public final class StubHomeRepository: HomeRepositoryProtocol {

    /// If non-nil, `fetchHome()` throws this error instead of
    /// returning the fixture. Reset between test calls to simulate
    /// "first call throws, second call succeeds" retry scenarios.
    public var shouldThrow: HomeError?

    public init(shouldThrow: HomeError? = nil) {
        self.shouldThrow = shouldThrow
    }

    // MARK: - HomeRepositoryProtocol

    public func fetchHome() async throws -> HomeDashboard {
        if let error = shouldThrow {
            throw error
        }
        return Self.bankuserOneFixture
    }

    // MARK: - bankuser.one fixture

    /// Representative dashboard for the `bankuser.one` persona.
    ///
    /// 4 accounts (checking, savings, credit, investment) and
    /// 3 recent transactions — rich enough to verify that every
    /// AccountType case decodes and that transaction list rendering
    /// works, without being so large that it obscures test intent.
    public static let bankuserOneFixture: HomeDashboard = {
        let customer = Customer(
            id: "cust-001",
            displayName: "Alex Bankuser",
            email: "bankuser.one@acmebank.com"
        )

        let checking = Account(
            id: "acct-001",
            accountNumber: "****1234",
            accountType: .checking,
            balance: Decimal(string: "2450.75")!,
            currency: "USD"
        )
        let savings = Account(
            id: "acct-002",
            accountNumber: "****5678",
            accountType: .savings,
            balance: Decimal(string: "12000.00")!,
            currency: "USD"
        )
        let credit = Account(
            id: "acct-003",
            accountNumber: "****9012",
            accountType: .credit,
            balance: Decimal(string: "-450.25")!,
            currency: "USD"
        )
        let investment = Account(
            id: "acct-004",
            accountNumber: "****3456",
            accountType: .investment,
            balance: Decimal(string: "45000.00")!,
            currency: "USD"
        )

        // Use a known fixed date so assertions against fixture data
        // are deterministic regardless of when the test runs.
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let tx1 = Transaction(
            id: "tx-001",
            accountId: "acct-001",
            description: "Coffee Shop",
            amount: Decimal(string: "-4.50")!,
            currency: "USD",
            date: baseDate
        )
        let tx2 = Transaction(
            id: "tx-002",
            accountId: "acct-001",
            description: "Payroll Deposit",
            amount: Decimal(string: "3200.00")!,
            currency: "USD",
            date: Date(timeIntervalSince1970: 1_699_990_000)
        )
        let tx3 = Transaction(
            id: "tx-003",
            accountId: "acct-002",
            description: "Transfer to Savings",
            amount: Decimal(string: "-500.00")!,
            currency: "USD",
            date: Date(timeIntervalSince1970: 1_699_980_000)
        )

        return HomeDashboard(
            customer: customer,
            accounts: [checking, savings, credit, investment],
            recentTransactions: [tx1, tx2, tx3]
        )
    }()
}
