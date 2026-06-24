import Foundation

/// Static fixtures for SwiftUI previews of the Home dashboard.
///
/// Two fixtures are provided so preview canvases can demonstrate both
/// the "with segment badge" (PREMIER) and "no badge" (nil segment)
/// states without coupling preview code to `StubHomeRepository`.
///
/// These are compile-time preview helpers only — they are never used
/// in production code or test targets.
enum HomePreviewFixtures {

    // MARK: - Primary fixture — PREMIER segment

    /// A dashboard representing a premier-tier customer.
    ///
    /// Use this fixture to preview the `SegmentBadgeView` badge
    /// rendered on the `SignedInCardView` name row.
    static let premierCustomerDashboard: HomeDashboard = {
        let customer = Customer(
            id: "cust-premier-001",
            firstName: "Ada",
            lastName: "Lovelace",
            email: "ada.lovelace@acmebank.com",
            phoneNumber: "+1-416-555-0101",
            segment: "PREMIER"
        )
        return HomeDashboard(
            customer: customer,
            accounts: sampleAccounts,
            recentTransactions: sampleTransactions
        )
    }()

    // MARK: - Secondary fixture — nil segment (no badge)

    /// A dashboard representing a standard customer with no segment.
    ///
    /// Use this fixture to verify that the `SignedInCardView` name row
    /// layout is unchanged (no badge, no layout shift) when
    /// `customer.segment` is `nil`.
    static let noSegmentCustomerDashboard: HomeDashboard = {
        let customer = Customer(
            id: "cust-standard-001",
            firstName: "Grace",
            lastName: "Hopper",
            email: "grace.hopper@acmebank.com",
            phoneNumber: "+1-416-555-0202",
            segment: nil
        )
        return HomeDashboard(
            customer: customer,
            accounts: sampleAccounts,
            recentTransactions: sampleTransactions
        )
    }()

    // MARK: - Shared sample data

    private static let sampleAccounts: [Account] = [
        Account(
            id: "acct-prev-001",
            name: "Unlimited Chequing",
            maskedNumber: "4821",
            balance: Decimal(string: "4287.52")!,
            availableBalance: Decimal(string: "4287.52")!,
            type: .chequing,
            currencyCode: "USD"
        ),
        Account(
            id: "acct-prev-002",
            name: "High-Interest Savings",
            maskedNumber: "9203",
            balance: Decimal(string: "18940.00")!,
            availableBalance: Decimal(string: "18940.00")!,
            type: .savings,
            currencyCode: "USD"
        )
    ]

    private static let sampleTransactions: [Transaction] = [
        Transaction(
            id: "txn-prev-001",
            accountId: "acct-prev-001",
            description: "Coffee Bar",
            amount: Decimal(string: "-4.75")!,
            postedDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: "dining",
            merchantName: "Coffee Bar"
        )
    ]
}
