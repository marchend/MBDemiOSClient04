import Foundation
import UIKit

/// Cold-launch refresh-token reuse.
///
/// When the user previously opted into "Keep me signed in", the
/// `LoginViewModel` persisted the refresh token under the
/// `KeychainTokenStore`'s refresh service. On the NEXT cold launch we
/// look that token up and \u2014 if it's still valid \u2014 mint a fresh ID +
/// access pair through `OktaAuthenticating.refresh(refreshToken:)` so
/// the user lands directly on the Landing screen without re-entering
/// their password.
///
/// Failure modes (network, IdP-rejected stale refresh, malformed ID
/// token) are surfaced as typed `AuthError`s so the composition root
/// can react with a single `catch` arm: clear the stale refresh token
/// from the keychain and fall through to Login. That "clear on any
/// throw" policy lives in the caller, not here \u2014 the restorer's job
/// is to either return a fresh `UserSession` or throw a meaningful
/// reason.
///
/// SDK isolation: this file imports nothing Okta-specific. The auth
/// seam is the neutral `OktaAuthenticating` protocol, so tests inject
/// a fake without ever touching the real SDK (per the prior lesson
/// "Put the IdP SDK behind a NEUTRAL protocol seam").
public enum SessionRestorer {
    /// Restore a `UserSession` from a previously persisted refresh
    /// token.
    ///
    /// - Parameters:
    ///   - refreshToken: the refresh token loaded from the keychain.
    ///   - authClient: the auth-protocol seam. Production callers pass
    ///     the live `OktaDirectAuthClient`; tests inject a scriptable
    ///     fake.
    ///   - deviceName: closure returning the current device name. The
    ///     production default reads `UIDevice.current.name`; tests
    ///     pass a deterministic string so a CI runner's host name
    ///     doesn't leak into the assertion surface.
    /// - Returns: a fresh `UserSession` populated from the new ID
    ///   token's claims and the new access token.
    /// - Throws: `AuthError.malformedToken` if the refresh response
    ///   omits or returns an undecodable ID token; whatever the auth
    ///   client throws otherwise (`.network`, `.invalidCredentials`,
    ///   `.notConfigured`, etc.) propagates unchanged.
    public static func restore(
        refreshToken: String,
        authClient: OktaAuthenticating,
        deviceName: @autoclosure () -> String = UIDevice.current.name
    ) async throws -> UserSession {
        let tokens = try await authClient.refresh(refreshToken: refreshToken)

        // A refresh response that omits the ID token is a plumbing bug
        // \u2014 we can't construct a `UserSession` without claims. Surface
        // as `.malformedToken` (the same typed error
        // `IDTokenDecoder.decode` throws on a structural failure) so
        // the composition root's "any throw \u2192 clear stale token" arm
        // catches it without a special case.
        guard let idToken = tokens.idToken else {
            throw AuthError.malformedToken
        }

        let claims = try IDTokenDecoder.decode(idToken)

        return UserSession(
            userId: claims.sub,
            // Mirror LoginViewModel's display fallback chain so a
            // tenant returning only `sub` still produces a usable
            // welcome string instead of an empty headline.
            displayName: claims.name ?? claims.email ?? claims.sub,
            email: claims.email ?? "",
            accessToken: tokens.accessToken,
            authTimestamp: claims.auth_time ?? Date(),
            deviceName: deviceName()
        )
    }
}
