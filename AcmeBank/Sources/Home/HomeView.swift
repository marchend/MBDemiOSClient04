import SwiftUI

/// Home/Dashboard screen shown after a successful sign-in.
///
/// Responsibilities:
/// - Owns a `HomeViewModel` (created via `@StateObject` from the
///   injected `session` and `onSignOut` closure).
/// - Calls `viewModel.load()` on first appear via `.task`.
/// - Renders four view states: idle, loading, loaded, error.
/// - Exposes a Log-Out button in the navigation bar that calls
///   `viewModel.signOut()`, which clears the Keychain and fires
///   `onSignOut` so `AcmeBankApp` can nil-out the session.
///
/// Accessibility identifiers are stable across layout/copy changes so
/// that UI tests can locate elements without chasing visual updates.
struct HomeView: View {

    // MARK: - Dependencies

    @StateObject private var viewModel: HomeViewModel

    // MARK: - Init

    /// - Parameters:
    ///   - session: The authenticated `UserSession` forwarded to
    ///     `HomeViewModel` for Bearer-token attachment on BFF requests.
    ///   - onSignOut: Closure invoked when the user taps Log Out (or
    ///     when a 401 is received). `AcmeBankApp` supplies
    ///     `{ session = nil }` here to pop back to `LoginView`.
    init(session: UserSession, onSignOut: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            session: session,
            onSignOut: onSignOut
        ))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    Color.clear

                case .loading:
                    ProgressView("Loading…")
                        .accessibilityIdentifier("home.loading")

                case .loaded(let dashboard):
                    dashboardContent(dashboard)

                case .error(let error):
                    errorContent(error)
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") {
                        viewModel.signOut()
                    }
                    .accessibilityIdentifier("home.logOut")
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func dashboardContent(_ dashboard: HomeDashboard) -> some View {
        List {
            Section("Welcome") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome, \(dashboard.customer.displayName)")
                        .font(.headline)
                        .accessibilityIdentifier("home.welcome")
                    Text(dashboard.customer.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("home.email")
                }
                .padding(.vertical, 4)
            }

            Section("Accounts") {
                ForEach(dashboard.accounts, id: \.id) { account in
                    AccountRow(account: account)
                }
            }

            Section("Recent Transactions") {
                ForEach(dashboard.recentTransactions, id: \.id) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .accessibilityIdentifier("home.dashboard")
    }

    @ViewBuilder
    private func errorContent(_ error: HomeError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("Something went wrong")
                .font(.headline)

            Button("Try Again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("home.retry")
        }
        .accessibilityIdentifier("home.error")
    }
}

// MARK: - Supporting row views

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.accountType.displayName)
                    .font(.body)
                Text(account.accountNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(account.balance, format: .currency(code: account.currency))
                .font(.body.monospacedDigit())
                .foregroundStyle(account.balance < 0 ? .red : .primary)
        }
    }
}

private struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.body)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(transaction.amount, format: .currency(code: transaction.currency))
                .font(.body.monospacedDigit())
                .foregroundStyle(transaction.amount < 0 ? .red : .green)
        }
    }
}

// MARK: - AccountType display helper

private extension AccountType {
    var displayName: String {
        switch self {
        case .checking:    return "Checking"
        case .savings:     return "Savings"
        case .credit:      return "Credit"
        case .investment:  return "Investment"
        case .unknown:     return "Account"
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView(
        session: UserSession(
            userId: "preview-user",
            displayName: "Ada Lovelace",
            email: "ada@acmebank.com",
            accessToken: "preview-access-token",
            authTimestamp: Date(),
            deviceName: "Preview Device"
        ),
        onSignOut: {}
    )
}
