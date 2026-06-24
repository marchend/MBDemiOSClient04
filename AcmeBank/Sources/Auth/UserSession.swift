import Foundation

/// Authenticated user + access token bundle passed forward through
/// coordinators after a successful sign-in.
///
/// Field list is fixed by the bootstrap spec (see bootstrap.md
/// section 4):
///   - `userId`         \u2192 `sub` claim from the ID token
///   - `displayName`    \u2192 `name` claim
///   - `email`          \u2192 `email` claim
///   - `accessToken`    \u2192 OAuth2 access token (NOT the ID token)
///   - `authTimestamp`  \u2192 `auth_time` claim, or `Date()` if absent
///   - `deviceName`     \u2192 `UIDevice.current.name` at sign-in time
///
/// Codable so the Keychain layer (PR 3 / PR 4) can persist it as a
/// single blob keyed by service. NO refresh-token field: refresh
/// tokens live in the keychain under their own service and are never
/// surfaced through `UserSession`, so a `UserSession` value can be
/// logged or rehydrated without leaking long-lived credentials.
public struct UserSession: Codable, Equatable {
    public let userId: String
    public let displayName: String
    public let email: String
    public let accessToken: String
    public let authTimestamp: Date
    public let deviceName: String

    public init(
        userId: String,
        displayName: String,
        email: String,
        accessToken: String,
        authTimestamp: Date,
        deviceName: String
    ) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.accessToken = accessToken
        self.authTimestamp = authTimestamp
        self.deviceName = deviceName
    }
}
