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

Okta tenant credentials are injected into the built `Info.plist` at build
time by `Scripts/inject_okta_config.sh` (a Run Script build phase on the
`AcmeBank` target). The script reads four env vars from the calling
process:

| Env var              | Example                                                  |
|----------------------|----------------------------------------------------------|
| `OKTA_ISSUER`        | `https://acmebank.okta.com/oauth2/default`               |
| `OKTA_CLIENT_ID`     | `0oa1abcDEFghijKLM5d7`                                   |
| `OKTA_REDIRECT_URI`  | `com.acmebank.mobile:/callback`                          |
| `OKTA_SCOPES`        | `openid profile email offline_access` (space-separated)  |

When an env var is unset the script writes the matching sentinel
`__OKTA_<KEY>_UNSET__` so the build still succeeds; at runtime
`OktaConfig.load()` detects the sentinel and returns `.notConfigured`
with a reason naming the missing key(s).

### Where to set the env vars

A `PhaseScriptExecution` runs in a **subshell** of the Xcode build
process — it sees the environment of the process that launched Xcode,
NOT your interactive shell's `~/.zshrc`. Pick the pattern matching how
you launch Xcode:

1. **GUI launch (Dock / Spotlight)** — set vars at the launchd
   session level so all GUI apps inherit them:
   ```bash
   launchctl setenv OKTA_ISSUER       "https://acmebank.okta.com/oauth2/default"
   launchctl setenv OKTA_CLIENT_ID    "0oa1abcDEFghijKLM5d7"
   launchctl setenv OKTA_REDIRECT_URI "com.acmebank.mobile:/callback"
   launchctl setenv OKTA_SCOPES       "openid profile email offline_access"
   ```
   Restart Xcode after running. Survives until logout.

2. **Shell launch (`xed .` from Terminal)** — export in your shell
   profile (`~/.zshrc`), then open Xcode from the same terminal:
   ```bash
   export OKTA_ISSUER="https://acmebank.okta.com/oauth2/default"
   # …etc
   xed .
   ```
   Xcode inherits the exporting shell's environment.

3. **CI / `xcodebuild` from CLI** — pass on the invoking command:
   ```bash
   OKTA_ISSUER=… OKTA_CLIENT_ID=… OKTA_REDIRECT_URI=… OKTA_SCOPES=… \
     xcodebuild build -scheme AcmeBank -destination '…'
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
