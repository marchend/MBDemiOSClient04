#!/usr/bin/env bash
# setup.sh — one-shot iOS project materialisation.
# Run after cloning so the generated AcmeBank.xcodeproj is created
# and opened in Xcode.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen via Homebrew (one-time)…"
  brew install xcodegen
fi

# Write the local Okta/API config the build's inject phase reads. This makes
# "press Run in Xcode" work no matter how/when Xcode was launched — the build
# no longer depends on Xcode inheriting the OKTA_* env. Values come from the
# current shell env, else launchctl (where the README has you set them).
{
  for v in OKTA_ISSUER OKTA_CLIENT_ID OKTA_REDIRECT_URI OKTA_SCOPES; do
    printf "%s='%s'\n" "$v" "${!v:-$(launchctl getenv "$v" 2>/dev/null || true)}"
  done
  printf "API_BASE_URL='%s'\n" \
    "${API_BASE_URL:-$(launchctl getenv API_BASE_URL 2>/dev/null || echo https://mbdemo-bff-develop.azurewebsites.net)}"
} > okta.local.env

if grep -q "OKTA_ISSUER=''" okta.local.env; then
  echo "⚠️  Okta is not configured — OKTA_* env vars are blank."
  echo "    Set them once (see README), e.g.:"
  echo "      launchctl setenv OKTA_ISSUER https://<tenant>.okta.com/oauth2/default"
  echo "    then re-run ./setup.sh."
fi

xcodegen generate

open -a Xcode *.xcodeproj 2>/dev/null || \
  echo "✓ Project generated. Open AcmeBank.xcodeproj in Xcode to start."
