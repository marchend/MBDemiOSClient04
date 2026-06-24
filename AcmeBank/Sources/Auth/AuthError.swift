import Foundation

/// Errors surfaced by the Auth layer to its callers (LoginViewModel in
/// a later PR). Deliberately small + closed so the UI's
/// `catch let e as AuthError` filter can map each case to a single
/// user-facing copy string.
///
/// Per the prior lesson "every escape path from a function whose caller
/// does `catch let e as TypedError` MUST itself be of TypedError":
/// post-SDK-success failures (JWT decode, keychain write) MUST also map
/// to AuthError cases rather than escape as a raw `Error` and collapse
/// to the generic "couldn't reach Okta" copy in the UI. The
/// `.malformedToken` case carries that responsibility for ID-token
/// decoding; keychain writes are treated as a best-effort cache in the
/// AuthService and never throw (handled in PR 3).
public enum AuthError: Error, Equatable {
    /// Username / password rejected by the IdP.
    case invalidCredentials
    /// Transport-layer failure reaching the IdP.
    case network
    /// IdP indicated additional factors are required; this app
    /// (bootstrap demo) does not handle MFA in the Direct-Auth flow.
    case mfaRequired
    /// Local config is missing or malformed (e.g. `OktaConfig.notConfigured`).
    /// `reason` is human-readable for logs / diagnostics.
    case notConfigured(String)
    /// ID-token JWT was not a well-formed three-segment base64url
    /// payload, or its claims could not be decoded. Surfaces post-SDK
    /// decode bugs as a typed error so the UI doesn't lie with a
    /// network-error banner.
    case malformedToken
}
