#!/bin/bash
#
# inject_okta_config.sh
#
# Build-time Run Script phase that bridges shell env vars (OKTA_ISSUER,
# OKTA_CLIENT_ID, OKTA_REDIRECT_URI, OKTA_SCOPES) into the built
# Info.plist so the app can read them at runtime via
# `Bundle.main.infoDictionary`.
#
# Why a Run Script and not an xcconfig: xcconfig `$(VAR)` references do
# NOT interpolate shell env vars — they chain other build settings — so
# the obvious-looking xcconfig path silently ships an app with empty
# values. Xcode passes the calling process's environment to build phase
# scripts, so plutil+env works reliably.
#
# Why no `set -e` on missing vars: this script must not hard-fail the
# build when the dev hasn't exported the Okta env vars (e.g. fresh
# clone, CI without secrets). Instead we write a sentinel value
# `__OKTA_<KEY>_UNSET__` so `OktaConfig.load()` can detect missing
# config at runtime and degrade gracefully.
#
# Ordered BEFORE "Copy Bundle Resources" in project.yml so the
# mutations land on the Info.plist that ships with the .app, not on a
# stale copy. The script edits `${TARGET_BUILD_DIR}/${INFOPLIST_PATH}`
# directly, which is the built Info.plist Xcode has already copied
# into the product.

set -u

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [[ ! -f "${PLIST}" ]]; then
    echo "warning: inject_okta_config.sh: Info.plist not found at ${PLIST}; skipping"
    exit 0
fi

inject_key() {
    local key="$1"
    local value="$2"
    local sentinel="__${key}_UNSET__"
    if [[ -n "${value}" ]]; then
        /usr/bin/plutil -replace "${key}" -string "${value}" "${PLIST}"
        echo "inject_okta_config.sh: wrote ${key} (real value)"
    else
        /usr/bin/plutil -replace "${key}" -string "${sentinel}" "${PLIST}"
        echo "inject_okta_config.sh: wrote ${key} = ${sentinel}"
    fi
}

inject_key "OKTA_ISSUER"       "${OKTA_ISSUER:-}"
inject_key "OKTA_CLIENT_ID"    "${OKTA_CLIENT_ID:-}"
inject_key "OKTA_REDIRECT_URI" "${OKTA_REDIRECT_URI:-}"
inject_key "OKTA_SCOPES"       "${OKTA_SCOPES:-}"
