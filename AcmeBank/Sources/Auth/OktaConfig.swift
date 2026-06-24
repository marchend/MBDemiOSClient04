import Foundation

/// Runtime Okta configuration loaded from the built Info.plist.
///
/// The `OKTA_*` keys appear in the source Info.plist as `$(VAR)`
/// references and are supplied as build settings by
/// `Config/AppConfig.xcconfig` (sentinel defaults, plus an optional
/// `#include?` of the gitignored `Config/Secrets.local.xcconfig` that
/// `setup.sh` writes from the OKTA_* env / launchctl). Xcode's
/// ProcessInfoPlistFile expands them into the built Info.plist. When a
/// value is unset its committed default is the sentinel
/// `__OKTA_<KEY>_UNSET__`, so the build always succeeds and missing
/// config surfaces here at runtime rather than as a build failure.
///
/// `OktaConfig.load()` reads from `Bundle.main.infoDictionary` by
/// default, but accepts an injectable dictionary for unit tests so we
/// can exercise the sentinel / partial / malformed-URL paths without
/// mutating the real bundle.
public enum OktaConfig: Equatable {
    /// All four keys present and well-formed.
    case configured(issuer: URL, clientId: String, redirectUri: URL, scopes: [String])
    /// At least one key is missing, sentinel-valued, or malformed.
    /// `reason` is human-readable and names the offending key(s) so
    /// the failure surfaces clearly in logs and developer diagnostics.
    case notConfigured(reason: String)

    /// The four keys this config reads from Info.plist.
    static let issuerKey       = "OKTA_ISSUER"
    static let clientIdKey     = "OKTA_CLIENT_ID"
    static let redirectUriKey  = "OKTA_REDIRECT_URI"
    static let scopesKey       = "OKTA_SCOPES"

    /// Load from the main bundle's Info.plist. Production call site.
    public static func load() -> OktaConfig {
        load(from: Bundle.main.infoDictionary ?? [:])
    }

    /// Load from an arbitrary dictionary. Test seam — production code
    /// should call `load()`. Visible to the test target via @testable
    /// import; declared internal (default) so it stays out of the
    /// public API surface.
    static func load(from info: [String: Any]) -> OktaConfig {
        let issuerRaw      = nonSentinelString(info[issuerKey])
        let clientIdRaw    = nonSentinelString(info[clientIdKey])
        let redirectRaw    = nonSentinelString(info[redirectUriKey])
        let scopesRaw      = nonSentinelString(info[scopesKey])

        // Collect ALL diagnostic problems (missing keys AND malformed
        // URL values) in declaration order before deciding to bail.
        // Previously we returned on the first missing-key check and
        // only validated URLs afterward — so a misconfigured plist
        // with `OKTA_ISSUER = "not a url"` AND a sentinel
        // `OKTA_CLIENT_ID` would report only the client-id problem,
        // and the developer would fix that, rebuild, and discover the
        // bad issuer URL in a second round. Collecting both in one
        // pass means the reason string is exhaustive on a single
        // build and the dev fixes all problems before the next run.
        var problems: [String] = []
        if issuerRaw    == nil { problems.append("missing \(issuerKey)") }
        if clientIdRaw  == nil { problems.append("missing \(clientIdKey)") }
        if redirectRaw  == nil { problems.append("missing \(redirectUriKey)") }
        if scopesRaw    == nil { problems.append("missing \(scopesKey)") }

        // Validate URLs for keys that ARE present and non-sentinel.
        // We still need to capture the parsed URL for the success
        // path, so we compute it eagerly and append a problem entry
        // when validation fails.
        var parsedIssuer: URL?
        if let raw = issuerRaw {
            if let url = URL(string: raw), url.scheme != nil {
                parsedIssuer = url
            } else {
                problems.append("malformed URL for \(issuerKey): \(raw)")
            }
        }

        var parsedRedirect: URL?
        if let raw = redirectRaw {
            if let url = URL(string: raw), url.scheme != nil {
                parsedRedirect = url
            } else {
                problems.append("malformed URL for \(redirectUriKey): \(raw)")
            }
        }

        // Scope list: present + non-sentinel + at least one token
        // after whitespace-splitting. We compute this eagerly for the
        // same reason as the URL parses above.
        var parsedScopes: [String] = []
        if let raw = scopesRaw {
            parsedScopes = raw
                .split(separator: " ", omittingEmptySubsequences: true)
                .map(String.init)
            if parsedScopes.isEmpty {
                problems.append("empty scope list for \(scopesKey)")
            }
        }

        if !problems.isEmpty {
            return .notConfigured(
                reason: "Okta config problem(s): \(problems.joined(separator: "; "))"
            )
        }

        // All four checks passed — by construction the optionals are
        // populated and clientIdRaw is non-nil.
        return .configured(
            issuer: parsedIssuer!,
            clientId: clientIdRaw!,
            redirectUri: parsedRedirect!,
            scopes: parsedScopes
        )
    }

    /// Returns the trimmed string if non-empty AND not a sentinel,
    /// otherwise `nil`. Sentinels follow the `__<KEY>_UNSET__`
    /// convention defined in `Config/AppConfig.xcconfig`.
    private static func nonSentinelString(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("__") && trimmed.hasSuffix("_UNSET__") { return nil }
        return trimmed
    }
}
