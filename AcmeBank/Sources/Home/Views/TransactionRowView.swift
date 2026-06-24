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

            Text(transaction.amount.formatted(currencyCode: transaction.currency))
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
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: transaction.date)
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
                currency: "USD",
                date: Date()
            )
        )
        TransactionRowView(
            transaction: Transaction(
                id: "t2",
                accountId: "a1",
                description: "Payroll Deposit",
                amount: Decimal(string: "3200.00")!,
                currency: "USD",
                date: Date()
            )
        )
    }
    .padding()
}
