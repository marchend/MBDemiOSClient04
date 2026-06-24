import Foundation

/// Payload claims extracted from an OIDC ID-token JWT.
///
/// Field names match the OIDC standard-claim spellings so a default
/// `JSONDecoder` (no custom key-coding) decodes them directly off the
/// base64url-decoded middle segment. `auth_time` is optional because
/// not every IdP issues it on every flow; when absent the caller
/// (`AuthService` in PR 3) substitutes `Date()`.
public struct IDTokenClaims: Codable, Equatable {
    public let sub: String
    public let name: String
    public let email: String
    public let auth_time: Date?

    public init(sub: String, name: String, email: String, auth_time: Date?) {
        self.sub = sub
        self.name = name
        self.email = email
        self.auth_time = auth_time
    }
}
