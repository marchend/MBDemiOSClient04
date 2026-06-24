import SwiftUI

/// A single row in the Accounts section of the Home screen.
///
/// Layout:
/// - Left: dark rounded-square icon tile (SF Symbol on navy tile)
/// - Middle: account name + account number (subtitle)
/// - Right: balance formatted via `Decimal.formatted(currencyCode:)`
///   with `\u{2212}` prefix for negatives; negative rows additionally
///   show `"<available> available"` subtext.
///
/// Zero colour-coded amounts: all text is `.primary` or `.secondary`.
struct AccountRowView: View {

    let account: Account

    // MARK: - Body

    var body: some View {
        HStack(spacing: 14) {
            iconTile
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.accountType.displayName)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(account.accountNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(account.balance.formatted(currencyCode: account.currency))
                    .font(.body.monospacedDigit())
                    .foregroundColor(.primary)

                if account.balance < 0 {
                    // Show absolute available balance as subtext when
                    // balance is negative (e.g. credit card owing).
                    // Never red — plain secondary style.
                    Text("\(account.balance.formattedAbsolute(currencyCode: account.currency)) available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Icon tile

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.acmeBrandNavy)
            Image(systemName: accountTypeIcon(account.accountType))
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - SF Symbol per account type

    private func accountTypeIcon(_ type: AccountType) -> String {
        switch type {
        case .credit:
            return "creditcard"
        case .checking, .savings:
            return "banknote"
        case .investment:
            return "chart.line.uptrend.xyaxis"
        case .unknown:
            return "dollarsign.circle"
        }
    }
}

// MARK: - AccountType display name

private extension AccountType {
    var displayName: String {
        switch self {
        case .checking:   return "Chequing"
        case .savings:    return "Savings"
        case .credit:     return "Credit"
        case .investment: return "Investment"
        case .unknown:    return "Account"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        AccountRowView(
            account: Account(
                id: "1",
                accountNumber: "****1234",
                accountType: .checking,
                balance: Decimal(string: "5200.50")!,
                currency: "USD"
            )
        )
        AccountRowView(
            account: Account(
                id: "2",
                accountNumber: "****5678",
                accountType: .credit,
                balance: Decimal(string: "-243.10")!,
                currency: "USD"
            )
        )
        AccountRowView(
            account: Account(
                id: "3",
                accountNumber: "****9012",
                accountType: .investment,
                balance: Decimal(string: "12345.00")!,
                currency: "USD"
            )
        )
    }
    .padding()
}
