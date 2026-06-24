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
