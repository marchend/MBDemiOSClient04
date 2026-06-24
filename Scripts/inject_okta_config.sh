#!/bin/bash
#
# inject_okta_config.sh
#
# Build-time Run Script phase that bridges shell env vars (OKTA_ISSUER,
# OKTA_CLIENT_ID, OKTA_REDIRECT_URI, OKTA_SCOPES, API_BASE_URL) into
# the built Info.plist so the app can read them at runtime via
# `Bundle.main.infoDictionary`.
#
# Why a Run Script and not an xcconfig: xcconfig `$(VAR)` references do
# NOT interpolate shell env vars — they chain other build settings —
# so the obvious-looking xcconfig path silently ships an app with empty
# values. Xcode passes the calling process's environment to build phase
# scripts, so plutil+env works reliably.
#
# Why no `set -e` on missing vars: this script must not hard-fail the
# build when the dev hasn't exported the env vars (e.g. fresh
# clone, CI without secrets). Instead we write a sentinel value
# `__<KEY>_UNSET__` so the consuming code can detect missing
# config at runtime and degrade gracefully.
#
# Ordered BEFORE "Copy Bundle Resources" in project.yml so the
# mutations land on the Info.plist that ships with the .app, not on a
# stale copy. The script edits `${TARGET_BUILD_DIR}/${INFOPLIST_PATH}`
# directly, which is the built Info.plist Xcode has already copied
# into the product.

set -u

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

# Stamp file declared as this phase's `outputFiles` in project.yml.
# It is NOT the built Info.plist (Xcode's ProcessInfoPlistFile task
# already claims that path; declaring it here too would trigger a
# "Multiple commands produce …" error). The stamp gives Xcode a real,
# unique file to track for this phase; we `touch` it on every
# successful run below.
STAMP="${DERIVED_FILE_DIR}/inject_okta_config.stamp"

if [[ ! -f "${PLIST}" ]]; then
    echo "warning: inject_okta_config.sh: Info.plist not found at ${PLIST}; skipping"
    # Still touch the stamp so Xcode's output-file bookkeeping is
    # satisfied even on the skip path; otherwise the phase would be
    # considered perpetually out-of-date for a different reason
    # (missing declared output) and could produce spurious warnings.
    mkdir -p "${DERIVED_FILE_DIR}"
    /usr/bin/touch "${STAMP}"
    exit 0
fi

# Why we check `plutil`'s exit code explicitly rather than relying on
# `set -e`: the env-var-unset case must stay graceful (sentinel write),
# but a `plutil -replace` failure means a genuine problem — the target
# key is absent from the source Info.plist, the plist is corrupt, or
# the file isn't writable. Those are build errors, not "degrade at
# runtime" cases, so we fail the build here with a clear message
# instead of silently shipping a plist missing the keys (which
# would surface later as `.notConfigured` at runtime with no
# build-time signal of why).
inject_key() {
    local key="$1"
    local value="$2"
    local sentinel="__${key}_UNSET__"
    local write_value="${value:-${sentinel}}"
    if ! /usr/bin/plutil -replace "${key}" -string "${write_value}" "${PLIST}"; then
        echo "error: inject_okta_config.sh: failed to write ${key} to ${PLIST}" >&2
        exit 1
    fi
    if [[ -n "${value}" ]]; then
        echo "inject_okta_config.sh: wrote ${key} (real value)"
    else
        echo "inject_okta_config.sh: wrote ${key} = ${sentinel}"
    fi
}

# Config fallback: when the build process didn't INHERIT the OKTA_* /
# API_BASE_URL env (the common case — Xcode launched before `launchctl
# setenv`, so its build-script subshell has a stale environment), read the
# values from a gitignored `okta.local.env` written by setup.sh. This makes
# the "press Run in Xcode" flow deterministic instead of depending on how/when
# Xcode was launched. The shell env still WINS (only blanks are filled), so an
# explicit `export` / command-line build keeps overriding the file.
LOCAL_ENV="${SRCROOT}/okta.local.env"
if [[ -f "${LOCAL_ENV}" ]]; then
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        k="${line%%=*}"
        case "${k}" in
            OKTA_ISSUER|OKTA_CLIENT_ID|OKTA_REDIRECT_URI|OKTA_SCOPES|API_BASE_URL) ;;
            *) continue ;;
        esac
        if [[ -z "${!k:-}" ]]; then
            v="${line#*=}"; v="${v%\'}"; v="${v#\'}"; v="${v%\"}"; v="${v#\"}"
            export "${k}=${v}"
        fi
    done < "${LOCAL_ENV}"
    echo "inject_okta_config.sh: loaded fallback config from ${LOCAL_ENV}"
fi

inject_key "OKTA_ISSUER"       "${OKTA_ISSUER:-}"
inject_key "OKTA_CLIENT_ID"    "${OKTA_CLIENT_ID:-}"
inject_key "OKTA_REDIRECT_URI" "${OKTA_REDIRECT_URI:-}"
inject_key "OKTA_SCOPES"       "${OKTA_SCOPES:-}"
inject_key "API_BASE_URL"      "${API_BASE_URL:-}"

# Stamp the declared output so Xcode's sandbox/output bookkeeping sees
# the file the phase promised to produce. `mkdir -p` guards against
# DERIVED_FILE_DIR not yet existing on a fully-clean build.
mkdir -p "${DERIVED_FILE_DIR}"
/usr/bin/touch "${STAMP}"
