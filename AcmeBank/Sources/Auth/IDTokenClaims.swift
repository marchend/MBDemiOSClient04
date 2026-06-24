import Foundation

/// Payload claims extracted from an OIDC ID-token JWT.
///
/// Field names match the OIDC standard-claim spellings so a default
/// `JSONDecoder` (no custom key-coding) decodes them directly off the
/// base64url-decoded middle segment.
///
/// Optionality mirrors what OIDC actually guarantees:
///   - `sub` is the only claim required by OIDC Core for an ID token,
///     so it stays non-optional. Its absence is a true malformed-token
///     condition.
///   - `name` is part of the `profile` scope; `email` is part of the
///     `email` scope. They're only present when the Okta app's scope
///     set includes them AND the user's profile is populated. A
///     misconfigured tenant (missing user profile, or app scopes not
///     including `profile` / `email`) would otherwise cause
///     `IDTokenDecoder.decode` to throw `.malformedToken` on an
///     otherwise-successful sign-in — a confusing failure mode. They
///     are optional here so the session builder (`AuthService` in PR 3
///     / `UserSession` construction) can decide whether to fail or
///     substitute a display fallback.
///   - `auth_time` is optional because not every IdP issues it on every
///     flow; when absent the caller substitutes `Date()`.
public struct IDTokenClaims: Codable, Equatable {
    public let sub: String
    public let name: String?
    public let email: String?
    public let auth_time: Date?

    public init(sub: String, name: String?, email: String?, auth_time: Date?) {
        self.sub = sub
        self.name = name
        self.email = email
        self.auth_time = auth_time
    }
}
