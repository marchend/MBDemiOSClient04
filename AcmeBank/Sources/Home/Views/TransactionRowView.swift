import SwiftUI

/// A single row in the Recent Transactions section of the Home screen.
///
/// Layout:
/// - Left: circular grey avatar with the first letter of the
///   transaction description
/// - Middle: description label + formatted date ("MMM d, yyyy")
/// - Right: signed amount — `\u{2212}` for negative values, always
///   `.primary` colour (never red or green)
struct TransactionRowView: View {

    let transaction: Transaction

    /// Currency the amount renders in. The BFF sends no per-transaction
    /// currency, so the caller supplies the owning account's currency
    /// (see `HomeDashboard.displayCurrency(for:)`). Passing it in — rather
    /// than hardcoding `"USD"` — keeps the transaction list in the same
    /// currency as the accounts (e.g. CAD), so a CAD account's activity no
    /// longer renders as `US$`.
    let currencyCode: String

    // MARK: - Body

    var body: some View {
        HStack(spacing: 14) {
            avatarView
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(transaction.amount.formatted(currencyCode: currencyCode))
                .font(.body.monospacedDigit())
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Private helpers

    private var avatarLetter: String {
        String(transaction.description.first ?? "?").uppercased()
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: transaction.postedDate)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemFill))
            Text(avatarLetter)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Static formatter cache

    /// `DateFormatter` is expensive to initialise — creating one per
    /// row in a scrolling list causes measurable jank on device.
    /// A single static instance shared across all `TransactionRowView`
    /// renders is sufficient because `string(from:)` is thread-safe
    /// once the formatter's properties are fixed.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
}

// MARK: - Preview

#Preview {
    VStack {
        TransactionRowView(
            transaction: Transaction(
                id: "t1",
                accountId: "a1",
                description: "Starbucks Coffee",
                amount: Decimal(string: "-5.75")!,
                postedDate: Date()
            ),
            currencyCode: "CAD"
        )
        TransactionRowView(
            transaction: Transaction(
                id: "t2",
                accountId: "a1",
                description: "Payroll Deposit",
                amount: Decimal(string: "3200.00")!,
                postedDate: Date()
            ),
            currencyCode: "CAD"
        )
    }
    .padding()
}
