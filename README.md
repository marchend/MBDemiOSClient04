# AcmeBank iOS

An iOS 17 banking app built with SwiftUI, MVVM + Coordinator, and Okta OIDC authentication.

## Quick Start

```bash
git clone <repo>
cd <repo>
./setup.sh
```

`setup.sh` installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) if missing,
materialises `AcmeBank.xcodeproj` from `project.yml`, and opens the project in Xcode.

**Manual fallback** (for environments that block shell scripts):

```bash
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

## Running Tests

```bash
xcodegen generate   # skip if .xcodeproj already present
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## Okta build configuration

Okta tenant credentials (and the BFF base URL) are supplied as **build
settings** and expanded into the built `Info.plist` by Xcode. The source
`Info.plist` references them as `$(OKTA_ISSUER)`, `$(API_BASE_URL)`, etc.;
`Config/AppConfig.xcconfig` defines them (optionally including the gitignored
`Config/Secrets.local.xcconfig` written by `setup.sh`); and Xcode's
`ProcessInfoPlistFile` bakes the values in via `-expandbuildsettings`.

Because the values are produced by the **same task that writes the plist**,
they survive *every* build — clean or incremental — and the build does **not**
depend on how or when Xcode was launched. (The earlier approach mutated the
built plist from a Run Script phase, which `ProcessInfoPlistFile` could re-run
after and clobber — the "needs a Clean Build Folder every time" bug. That is
gone.)

Set the values once (the example uses `launchctl`, which persists for the
login session), then run `./setup.sh`:

| Setting             | Example                                                  |
|---------------------|----------------------------------------------------------|
| `OKTA_ISSUER`       | `https://acmebank.okta.com/oauth2/default`               |
| `OKTA_CLIENT_ID`    | `0oa1abcDEFghijKLM5d7`                                   |
| `OKTA_REDIRECT_URI` | `com.acmebank.mobile:/callback`                          |
| `OKTA_SCOPES`       | `openid profile email offline_access` (space-separated)  |
| `API_BASE_URL`      | `https://acmebank-bff.example.com`                       |

```bash
launchctl setenv OKTA_ISSUER       "https://acmebank.okta.com/oauth2/default"
launchctl setenv OKTA_CLIENT_ID    "0oa1abcDEFghijKLM5d7"
launchctl setenv OKTA_REDIRECT_URI "com.acmebank.mobile:/callback"
launchctl setenv OKTA_SCOPES       "openid profile email offline_access"
launchctl setenv API_BASE_URL      "https://acmebank-bff.example.com"
./setup.sh        # captures them into Config/Secrets.local.xcconfig
```

`setup.sh` reads each value from your shell env, falling back to
`launchctl getenv`. You can instead `export` them in your shell before running
`./setup.sh`, or edit `Config/Secrets.local.xcconfig` directly. When a value
is unset, the committed default in `Config/AppConfig.xcconfig` is the sentinel
`__OKTA_<KEY>_UNSET__`, so the build still succeeds and `OktaConfig.load()`
reports `.notConfigured` at runtime, naming the missing key(s). After changing
a value, re-run `./setup.sh` (or just rebuild) — **no Clean Build Folder
needed.**

## Project Structure

See [CLAUDE.md](CLAUDE.md) for the full architecture reference, planned structure,
and deferred work list.

## Tech Stack

| Concern | Choice |
|---------|--------|
| Platform | iOS 17+, Xcode 16.0+ |
| Language | Swift 5.10 |
| UI | SwiftUI |
| Architecture | MVVM + Coordinator |
| Auth | Okta OIDC (`okta-mobile-swift`) |
| Networking | `URLSession` + async/await |
| Project | XcodeGen (`project.yml`) |

## Status

This is the **bootstrap scaffold** — the runnable shell the team merges on day one.
Feature work (auth, screens, networking, design system) lands in subsequent story PRs.
See [CLAUDE.md](CLAUDE.md) for the full deferred-work list.
