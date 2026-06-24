# AcmeBank — Agent / Developer Reference

## Project Overview
AcmeBank is an iOS 17 banking app built with SwiftUI and MVVM + Coordinator architecture.
It lets customers view accounts, review transactions, initiate transfers, and manage cards,
authenticated via Okta OIDC. This scaffold is the Hello-World bootstrap; all product
features are deferred to subsequent story PRs.

## Tech Stack
| Concern | Choice |
|---------|--------|
| Platform | iOS 17+, Xcode 16.0+ |
| Language | Swift 5.10 |
| UI Framework | SwiftUI (`@main App`, `WindowGroup`, `NavigationStack`) |
| Architecture | MVVM + Coordinator |
| Auth | Okta OIDC via `okta-mobile-swift` (deferred) |
| Networking | `URLSession` + async/await (deferred) |
| DI | Constructor injection; no service locator |
| Project file | XcodeGen `project.yml` — never hand-edit `.xcodeproj` |
| Bundle ID | `com.acmebank.mobile` |
| Test frameworks | XCTest (unit), XCUITest (critical UI flows) |

## How to Run Locally
```bash
git clone <repo>
cd <repo>
./setup.sh        # installs xcodegen via Homebrew, generates .xcodeproj, opens Xcode
```
Manual fallback (locked-down machines):
```bash
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```
Then in Xcode: **Product → Run** (⌘R) on the `AcmeBank` scheme targeting any iOS 17 simulator.

## How to Run Tests
```bash
xcodegen generate   # skip if .xcodeproj already present
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## Key Directory Structure

### Current (bootstrap)
```
project.yml                  ← XcodeGen spec (source of truth)
setup.sh                     ← one-shot post-clone setup
AcmeBank/
  App/
    AcmeBankApp.swift        ← @main entry (implemented)
    ContentView.swift        ← placeholder screen (implemented)
  Resources/
    Assets.xcassets/         ← AppIcon stub (implemented)
  AcmeBank.entitlements      ← keychain-access-groups stub (implemented)
  PrivacyInfo.xcprivacy      ← privacy manifest (implemented)
AcmeBankTests/
  AcmeBankTests.swift        ← smoke test (implemented)
AcmeBankUITests/
  AcmeBankUITests.swift      ← launch smoke test (implemented)
```

### Planned (from spec — future PRs)
```
AcmeBank/
  App/
    RootView.swift           ← auth-state switch (deferred)
    AppCoordinator.swift     ← root coordinator (deferred)
  Core/
    Auth/                    ← AuthService, KeychainStore, UserSession (deferred)
    Networking/              ← APIClient, APIRouter, APIError, RequestInterceptor (deferred)
    Notifications/           ← AppNotification, NotificationPublisher (deferred)
    Extensions/              ← Decimal+Currency, Date+Greeting, String+Initials (deferred)
  Domain/
    Models/                  ← Account, Transaction, Customer, TransferRequest (deferred)
    Repositories/            ← protocol definitions (deferred)
  Data/
    Remote/                  ← APIRepository implementations (deferred)
    Mock/                    ← MockRepository implementations (deferred)
  Features/
    Login/                   ← LoginCoordinator, LoginView, LoginViewModel (deferred)
    Home/                    ← HomeCoordinator, HomeView, HomeViewModel (deferred)
    Accounts/, Transfer/, Cards/ ← future features (deferred)
  DesignSystem/
    Colors.swift             ← monochrome palette (deferred)
    Typography.swift         ← font scale helpers (deferred)
AcmeBankTests/
  Core/Auth/                 ← AuthServiceTests (deferred)
  Features/Login/            ← LoginViewModelTests (deferred)
  Features/Home/             ← HomeViewModelTests (deferred)
AcmeBankUITests/
  LoginUITests.swift         ← end-to-end login flow (deferred)
  TransferUITests.swift      ← end-to-end transfer flow (deferred)
```

## Planned Architecture (from spec)

- **MVVM + Coordinator** — Views are pure SwiftUI structs; ViewModels are
  `final class: ObservableObject`; Coordinators own `NavigationStack` path
  and inject dependencies. *(deferred — future PR)*
- **Okta OIDC** — browser-based sign-in via `okta-mobile-swift`; tokens
  persisted to Keychain via `KeychainStore`. *(deferred — future PR)*
- **Networking** — `APIClient` wraps `URLSession`; `APIRouter` enum drives
  endpoints; `RequestInterceptor` injects Bearer token + triggers refresh.
  *(deferred — future PR)*
- **Domain / Repository pattern** — protocol-only `Domain/Repositories/`;
  concrete `Data/Remote/` and `Data/Mock/` implementations; ViewModels depend
  only on protocols. *(deferred — future PR)*
- **Home Dashboard BFF** — `GET /v1/home` with Okta token; `HomeDashboard`
  decoded with `.convertFromSnakeCase` + `.iso8601`. *(deferred — future PR)*
- **Internal notifications** — `NotificationCenter` typed via `AppNotification`
  enum; `NotificationPublisher` helper; `AppCoordinator` subscribes (Combine
  sink) to `sessionExpired`. *(deferred — future PR)*
- **Design system** — strictly monochrome (navy + white + greys);
  `Color.acmeNavy`, `Color.acmeBackground`, etc.; Dynamic-Type-aware fonts.
  *(deferred — future PR)*
- **SwiftLint** — `.swiftlint.yml` at repo root; CI enforces zero violations.
  *(deferred — future PR)*
- **CI** — `ios-build.yml`; `xcodebuild test` on every PR; `-warnings-as-errors`;
  xcconfig injects `API_BASE_URL`. *(deferred — future PR)*

### Keychain note for future feature agents
Any query dictionary that touches `SecItem*` APIs **must** include
`kSecUseDataProtectionKeychain: true` so tests pass in CI's
`CODE_SIGNING_ALLOWED=NO` simulator environment.

## Deferred Work (bootstrap cutoff)
- Okta OIDC auth (`AuthService`, `KeychainStore`, `UserSession`) — future PR
- MVVM + Coordinator scaffolding (`AppCoordinator`, `TabBarCoordinator`, etc.) — future PR
- Networking layer (`APIClient`, `APIRouter`, `APIError`, `RequestInterceptor`) — future PR
- Domain models (`Account`, `Transaction`, `Customer`, `TransferRequest`) — future PR
- Repository protocols + mock/API implementations — future PR
- Home Dashboard BFF integration — future PR
- All feature screens (Login, Home, Transfer, Cards, Accounts, More) — future PRs
- Design system tokens (`Colors.swift`, `Typography.swift`) — future PR
- Internal notifications (`AppNotification`, `NotificationPublisher`) — future PR
- RootView auth-state switching — future PR
- SwiftLint config + CI workflow — future PR
- xcconfig / `API_BASE_URL` injection — future PR
- XCUITest critical flows (login, transfer, sign-out) — future PRs

## Git Workflow

> **Default PR target branch: `develop`.** Every feature/refactor/docs PR
> opens against `develop`. PRs are only opened against `qa`, `uat`, or
> `main` for explicit promotion PRs.

**Branch model (`develop` → `qa` → `uat` → `main`):**

| Branch  | Role                                 | Receives PRs from              | Promotes to |
|---------|--------------------------------------|--------------------------------|-------------|
| develop | Default integration branch           | feature branches               | qa          |
| qa      | First quality gate                   | develop (promotion PR)         | uat         |
| uat     | Pre-prod acceptance                  | qa (promotion PR)              | main        |
| main    | Production / release tags            | uat (promotion PR)             | tagged only |

All feature PRs MUST target `develop`. Never open a feature PR against
`qa`, `uat`, or `main`. Promotions happen via dedicated promotion PRs.
