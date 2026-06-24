import SwiftUI

/// Home/Dashboard screen shown after a successful sign-in.
///
/// Layout (top to bottom, no `NavigationStack`):
///   1. `BrandBarView` — pinned at the top, always visible.
///   2. `ScrollView` — greeting header + signed-in card + accounts
///      section + transactions section, expanding to fill available
///      space.
///   3. Log Out button strip — pinned outside the scroll region at the
///      bottom so it is always reachable without scrolling.
///
/// State machine driven by `HomeViewModel.state`:
///   - `.idle`    → transparent placeholder (before `.task` fires)
///   - `.loading` → centred `ProgressView`
///   - `.loaded`  → the full scrollable dashboard
///   - `.error`   → error message + "Retry" button
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
        VStack(spacing: 0) {
            BrandBarView()

            Group {
                switch viewModel.state {
                case .idle:
                    Color.clear

                case .loading:
                    loadingContent

                case .loaded(let dashboard):
                    dashboardContent(dashboard)

                case .error(let error):
                    errorContent(error)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            logOutStrip
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Loading content

    private var loadingContent: some View {
        ProgressView("Loading\u{2026}")
            .accessibilityIdentifier("home.loading")
    }

    // MARK: - Dashboard content

    @ViewBuilder
    private func dashboardContent(_ dashboard: HomeDashboard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Greeting header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Good day,")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(dashboard.customer.displayName)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("home.welcome")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Signed-in identity card (passes segment for badge rendering)
                SignedInCardView(
                    displayName: dashboard.customer.displayName,
                    customerId: dashboard.customer.id,
                    segment: dashboard.customer.segment
                )
                .padding(.horizontal, 20)

                // Accounts section
                sectionCard(header: "Accounts") {
                    ForEach(dashboard.accounts, id: \.id) { account in
                        AccountRowView(account: account)
                        if account.id != dashboard.accounts.last?.id {
                            Divider()
                                .padding(.leading, 58)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Recent Transactions section
                sectionCard(header: "Recent Transactions") {
                    if dashboard.recentTransactions.isEmpty {
                        Text("No recent transactions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(dashboard.recentTransactions, id: \.id) { tx in
                            TransactionRowView(transaction: tx,
                                               currencyCode: dashboard.displayCurrency(for: tx))
                            if tx.id != dashboard.recentTransactions.last?.id {
                                Divider()
                                    .padding(.leading, 54)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Bottom padding clears the pinned Log Out strip.
                Color.clear.frame(height: 16)
            }
        }
        .accessibilityIdentifier("home.dashboard")
    }

    // MARK: - Section card container

    @ViewBuilder
    private func sectionCard<Content: View>(
        header: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Error content

    @ViewBuilder
    private func errorContent(_ error: HomeError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Something went wrong")
                .font(.headline)
                .foregroundColor(.primary)

            Text(errorMessage(for: error))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await viewModel.load() }
            } label: {
                Text("Retry")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color.acmeBrandNavy)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityIdentifier("home.retry")
        }
        .padding()
        .accessibilityIdentifier("home.error")
    }

    private func errorMessage(for error: HomeError) -> String {
        switch error {
        case .unauthorized:
            // NOTE: This branch is intentionally unreachable in normal operation.
            // `HomeViewModel.load()` handles `.unauthorized` by calling
            // `clearKeychainAndSignOut()` which fires `onSignOut` and routes away
            // before SwiftUI ever renders the error view. The case is kept here
            // to keep the `switch` exhaustive — if the routing behaviour changes
            // in the future, this string will be shown rather than silently falling
            // through to a generic message.
            return "Your session has expired. Please sign in again."
        case .networkFailure:
            return "Couldn\u{2019}t reach Acme Bank. Please check your connection and try again."
        }
    }

    // MARK: - Log Out strip

    /// A white strip containing the Log Out button, pinned outside the
    /// `ScrollView` so it remains reachable regardless of scroll
    /// position. A `Divider` above provides visual separation.
    private var logOutStrip: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                viewModel.signOut()
            } label: {
                Text("Log out")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.acmeBrandNavy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .accessibilityIdentifier("home.logOut")
            .background(Color(.systemBackground))
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
