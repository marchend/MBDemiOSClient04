# Bootstrap Plan — AcmeBank iOS App

## In scope (this PR)

### Project Name & Tech Stack
- **App Name:** AcmeBank
- **Platform:** iOS 17+, Swift 5.10, SwiftUI
- **Architecture:** MVVM + Coordinator (deferred to features; entry point is a simple SwiftUI App)
- **Project file:** XcodeGen `project.yml` (never hand-crafted `.xcodeproj`)
- **Test framework:** XCTest (unit) + XCUITest target declared (empty stub, see note)
- **Minimum Xcode:** 16.0
- **Bundle ID:** `com.acmebank.mobile`

### Directory Structure (Hello World only)
```
.
├── project.yml                  # XcodeGen spec
├── setup.sh                     # one-shot: installs xcodegen + generates .xcodeproj
├── .gitignore                   # iOS / XcodeGen / macOS ignores
├── bootstrap_plan.md
├── CLAUDE.md
├── AGENT.md
├── README.md
│
├── AcmeBank/
│   ├── App/
│   │   ├── AcmeBankApp.swift    # @main SwiftUI entry point (WindowGroup + ContentView)
│   │   └── ContentView.swift    # "AcmeBank" placeholder label
│   ├── Resources/
│   │   └── Assets.xcassets/
│   │       ├── Contents.json
│   │       └── AppIcon.appiconset/
│   │           └── Contents.json
│   ├── AcmeBank.entitlements    # keychain-access-groups stub
│   └── PrivacyInfo.xcprivacy   # privacy manifest stub
│
├── AcmeBankTests/
│   └── AcmeBankTests.swift      # single smoke test (ContentView initializes)
│
└── AcmeBankUITests/
    └── AcmeBankUITests.swift    # minimal XCUITest stub (app launches)
```

### Files created in this PR
| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen spec — app + unit-test + UI-test targets |
| `setup.sh` | Post-clone helper: installs xcodegen, generates project, opens Xcode |
| `.gitignore` | Ignores generated `.xcodeproj`, `DerivedData`, macOS noise |
| `AcmeBank/App/AcmeBankApp.swift` | SwiftUI `@main` entry point |
| `AcmeBank/App/ContentView.swift` | Placeholder "AcmeBank" screen |
| `AcmeBank/Resources/Assets.xcassets/Contents.json` | Asset catalog root |
| `AcmeBank/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | AppIcon stub (prevents actool error) |
| `AcmeBank/AcmeBank.entitlements` | Keychain access group stub |
| `AcmeBank/PrivacyInfo.xcprivacy` | Privacy manifest (UserDefaults reason CA92.1) |
| `AcmeBankTests/AcmeBankTests.swift` | Smoke test: `ContentView()` initialises |
| `AcmeBankUITests/AcmeBankUITests.swift` | UI test smoke: app launches |
| `CLAUDE.md` / `AGENT.md` | Project docs (identical) |
| `README.md` | Updated quick-start |

### How to run locally
```bash
git clone <repo>
cd <repo>
./setup.sh          # installs xcodegen, runs xcodegen generate, opens .xcodeproj
```
Then in Xcode: Product → Run (⌘R).

### How to run tests
```bash
xcodegen generate   # if project not yet materialised
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

### Definition of Hello World
The app launches on iOS Simulator showing a single screen with the text **"AcmeBank"** centred on a plain background. One unit test passes confirming `ContentView` initialises. One UI test passes confirming the app launches.

---

## Out of scope — deferred to future work

- **Okta OIDC authentication** (`AuthService`, `KeychainStore`, `UserSession`, Okta.plist) — future PR
- **MVVM + Coordinator pattern** (`AppCoordinator`, `LoginCoordinator`, `TabBarCoordinator`, `HomeCoordinator`, etc.) — future PR
- **Networking layer** (`APIClient`, `APIRouter`, `APIError`, `RequestInterceptor`) — future PR
- **Domain models** (`Account`, `Transaction`, `Customer`, `TransferRequest`) — future PR
- **Repository protocols** (`AccountRepositoryProtocol`, `TransactionRepositoryProtocol`, `CustomerRepositoryProtocol`) — future PR
- **Mock data layer** (`MockAccountRepository`, `MockTransactionRepository`, `MockCustomerRepository`) — future PR
- **Home Dashboard / BFF integration** (`GET /v1/home`, `HomeRepository`, `HomeDashboard` payload) — future PR
- **Login screen** (`LoginView`, `LoginViewModel`) — future PR
- **Home screen** (`HomeView`, `HomeViewModel`, `SignedInCardView`, `QuickActionsView`, `AccountRowView`) — future PR
- **Transfer, Cards, Accounts, More features** — future PRs
- **Design system tokens** (`Colors.swift`, `Typography.swift`) — future PR
- **Internal notifications** (`AppNotification`, `NotificationPublisher`, `NotificationKey`) — future PR
- **RootView** (auth-state switching Login ↔ TabBar) — future PR
- **SwiftLint** (`.swiftlint.yml` config, CI enforcement) — future PR
- **CI workflow** (`ios-build.yml`, `xcodebuild test` on PR, `-warnings-as-errors`) — future PR
- **xcconfig** for `API_BASE_URL` injection — future PR
- **`PrivacyInfo.xcprivacy`** additional API types beyond UserDefaults — future PRs
- **XCUITest flows** (Login, Transfer, Sign-out end-to-end) — future PRs (stub target ships now)
- **80%+ unit-test coverage** targets — future PRs as features land
