import XCTest
@testable import AcmeBank

/// Unit tests for `HomeDashboard.displayCurrency(for:)`.
///
/// Regression for the Recent Transactions list rendering amounts as
/// `US$` while the CAD accounts rendered `$` — `TransactionRowView`
/// previously hardcoded `"USD"`. The amount now renders in the owning
/// account's currency, derived here.
final class HomeDashboardCurrencyTests: XCTestCase {

    private func account(_ id: String, _ currency: String) -> Account {
        Account(id: id, name: "Acct \(id)", maskedNumber: "0000",
                balance: 0, availableBalance: 0, type: .chequing, currencyCode: currency)
    }

    private func tx(_ id: String, account accountId: String) -> Transaction {
        Transaction(id: id, accountId: accountId, description: "x",
                    amount: Decimal(10), postedDate: Date(timeIntervalSince1970: 0))
    }

    private func dashboard(accounts: [Account], transactions: [Transaction]) -> HomeDashboard {
        HomeDashboard(
            customer: Customer(id: "c1", firstName: "Demo", lastName: "User", email: "demo@acme.com"),
            accounts: accounts,
            recentTransactions: transactions
        )
    }

    func test_displayCurrency_usesOwningAccountCurrency() {
        let dash = dashboard(
            accounts: [account("a1", "CAD"), account("a2", "USD")],
            transactions: []
        )
        // A transaction on a CAD account must render in CAD — not the old
        // hardcoded USD that produced "US$" rows over a CAD dataset.
        XCTAssertEqual(dash.displayCurrency(for: tx("t1", account: "a1")), "CAD")
        XCTAssertEqual(dash.displayCurrency(for: tx("t2", account: "a2")), "USD")
    }

    func test_displayCurrency_fallsBackToFirstAccount_whenOwnerMissing() {
        let dash = dashboard(accounts: [account("a1", "CAD")], transactions: [])
        // accountId absent from the set → first account's currency.
        XCTAssertEqual(dash.displayCurrency(for: tx("t9", account: "unknown")), "CAD")
    }

    func test_displayCurrency_fallsBackToUSD_whenNoAccounts() {
        let dash = dashboard(accounts: [], transactions: [])
        XCTAssertEqual(dash.displayCurrency(for: tx("t9", account: "x")), "USD")
    }
}
