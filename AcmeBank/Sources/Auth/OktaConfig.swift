import Foundation

/// Runtime Okta configuration loaded from the built Info.plist.
///
/// The four `OKTA_*` keys are written into the app's Info.plist at build
/// time by `Scripts/inject_okta_config.sh`, which reads the matching
/// env vars from the calling process. When an env var is unset the
/// script writes a sentinel string `__OKTA_<KEY>_UNSET__` instead, so
/// the build always succeeds and missing config surfaces here at
/// runtime rather than as a build failure.
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

        // Collect missing keys in declaration order so the reason
        // string is stable and grep-friendly.
        var missing: [String] = []
        if issuerRaw    == nil { missing.append(issuerKey) }
        if clientIdRaw  == nil { missing.append(clientIdKey) }
        if redirectRaw  == nil { missing.append(redirectUriKey) }
        if scopesRaw    == nil { missing.append(scopesKey) }

        if !missing.isEmpty {
            return .notConfigured(
                reason: "Missing Okta config key(s): \(missing.joined(separator: ", "))"
            )
        }

        guard let issuer = URL(string: issuerRaw!), issuer.scheme != nil else {
            return .notConfigured(reason: "Malformed URL for \(issuerKey): \(issuerRaw!)")
        }
        guard let redirectUri = URL(string: redirectRaw!), redirectUri.scheme != nil else {
            return .notConfigured(reason: "Malformed URL for \(redirectUriKey): \(redirectRaw!)")
        }

        let scopes = scopesRaw!
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)

        if scopes.isEmpty {
            return .notConfigured(reason: "Empty scope list for \(scopesKey)")
        }

        return .configured(
            issuer: issuer,
            clientId: clientIdRaw!,
            redirectUri: redirectUri,
            scopes: scopes
        )
    }

    /// Returns the trimmed string if non-empty AND not a sentinel,
    /// otherwise `nil`. Sentinels follow the `__<KEY>_UNSET__`
    /// convention written by `Scripts/inject_okta_config.sh`.
    private static func nonSentinelString(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("__") && trimmed.hasSuffix("_UNSET__") { return nil }
        return trimmed
    }
}
