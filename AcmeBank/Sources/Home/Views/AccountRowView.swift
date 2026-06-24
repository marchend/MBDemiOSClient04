import SwiftUI

/// A single row in the Accounts section of the Home screen.
///
/// Layout:
/// - Left: dark rounded-square icon tile (SF Symbol on navy tile)
/// - Middle: account name + masked number (subtitle)
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
                Text(account.name)
                    .font(.body)
                    .foregroundColor(.primary)
                Text("\u{00B7}\u{00B7}\u{00B7}\u{00B7} \(account.maskedNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(account.balance.formatted(currencyCode: account.currencyCode))
                    .font(.body.monospacedDigit())
                    .foregroundColor(.primary)

                if account.balance < 0 {
                    // Show available balance as subtext when the balance
                    // is negative (e.g. credit card owing).
                    // Never red — plain secondary style.
                    Text("\(account.availableBalance.formatted(currencyCode: account.currencyCode)) available")
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
            Image(systemName: accountTypeIcon(account.type))
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - SF Symbol per account type

    private func accountTypeIcon(_ type: AccountType) -> String {
        switch type {
        case .credit:
            return "creditcard"
        case .chequing, .savings:
            return "banknote"
        case .investment:
            return "chart.line.uptrend.xyaxis"
        case .unknown:
            return "dollarsign.circle"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        AccountRowView(
            account: Account(
                id: "1",
                name: "Unlimited Chequing",
                maskedNumber: "1234",
                balance: Decimal(string: "5200.50")!,
                availableBalance: Decimal(string: "5200.50")!,
                type: .chequing,
                currencyCode: "USD"
            )
        )
        AccountRowView(
            account: Account(
                id: "2",
                name: "Rewards Credit Card",
                maskedNumber: "5678",
                balance: Decimal(string: "-243.10")!,
                availableBalance: Decimal(string: "4756.90")!,
                type: .credit,
                currencyCode: "USD"
            )
        )
        AccountRowView(
            account: Account(
                id: "3",
                name: "Growth Investment",
                maskedNumber: "9012",
                balance: Decimal(string: "12345.00")!,
                availableBalance: Decimal(string: "12345.00")!,
                type: .investment,
                currencyCode: "USD"
            )
        )
    }
    .padding()
}
