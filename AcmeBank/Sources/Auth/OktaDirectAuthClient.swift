import Foundation
import OktaDirectAuth

/// Token bundle returned by a successful Direct-Auth sign-in or
/// refresh. SDK-agnostic by design: the protocol seam returns this
/// type, NOT the SDK's `Token`, so the test target never has to
/// import `OktaDirectAuth`. (See prior lesson "Put the IdP SDK behind
/// a NEUTRAL protocol seam".)
public struct AuthTokens: Equatable {
    public let idToken: String
    public let accessToken: String
    public let refreshToken: String?

    public init(idToken: String, accessToken: String, refreshToken: String?) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

/// Protocol seam between `AuthService` (PR 3) and the live Okta
/// Direct-Auth SDK adapter below. A test in this PR injects a trivial
/// fake conforming to this protocol; an in-target stub for SwiftUI
/// previews can do the same. The neutral return type / error type
/// means downstream code never sees an SDK type, so the test target
/// does NOT import `OktaDirectAuth`.
public protocol OktaAuthenticating {
    func signIn(username: String, password: String) async throws -> AuthTokens
    func refresh(refreshToken: String) async throws -> AuthTokens
}

/// Live adapter wrapping `okta-mobile-swift` 2.x's
/// `DirectAuthenticationFlow`.
///
/// Constructed from an `OktaConfig.configured(...)`; surfaces
/// `.notConfigured` as `AuthError.notConfigured` to the caller so a
/// missing build-time env var fails with a clear typed error rather
/// than a misleading network banner.
///
/// Maps SDK status to typed `AuthError` per the bootstrap spec:
///   - `.success(token)`               -> returns `AuthTokens`
///   - `.mfaRequired` (any payload)    -> `.mfaRequired`
///   - `.continuation` (any payload)   -> `.mfaRequired`
///   - thrown SDK errors               -> `.network`
///
/// This file is the ONLY one in the Auth layer that imports
/// `OktaDirectAuth`, so an SDK major-version bump only needs to touch
/// here (status case names, `.password(...)` factor spelling) without
/// touching tests or `AuthService`.
public final class OktaDirectAuthClient: OktaAuthenticating {
    private let config: OktaConfig

    public init(config: OktaConfig) {
        self.config = config
    }

    public func signIn(username: String, password: String) async throws -> AuthTokens {
        let flow = try makeFlow()
        do {
            let status = try await flow.start(username, with: .password(password))
            return try map(status)
        } catch let error as AuthError {
            throw error
        } catch {
            // Any non-typed throw from the SDK (URLError, decode
            // failure inside the SDK, etc.) collapses to .network.
            // The plumbing-bug class (post-SDK-success keychain /
            // JWT-decode) is handled in AuthService — not here.
            throw AuthError.network
        }
    }

    public func refresh(refreshToken: String) async throws -> AuthTokens {
        // The 2.x SDK exposes refresh through AuthFoundation's
        // `Token.refresh(...)` API. PR 4's SessionRestorer is the
        // first real caller; for this PR we stage a typed stub that
        // surfaces `.network` if invoked, and PR 4 replaces this
        // body with the real AuthFoundation call site without
        // changing the protocol surface.
        _ = refreshToken
        throw AuthError.network
    }

    // MARK: - Private

    /// Build the SDK flow from our validated `OktaConfig`. Surfaces
    /// `.notConfigured` as a typed error so callers don't have to
    /// guard on the enum themselves.
    private func makeFlow() throws -> DirectAuthenticationFlow {
        switch config {
        case .notConfigured(let reason):
            throw AuthError.notConfigured(reason)
        case let .configured(issuer, clientId, _, scopes):
            return DirectAuthenticationFlow(
                issuer: issuer,
                clientId: clientId,
                scopes: scopes.joined(separator: " ")
            )
        }
    }

    /// Translate an SDK status into our neutral `AuthTokens` /
    /// `AuthError`. Each non-success branch maps to a single typed
    /// error case; the SDK enum is not surfaced beyond this file.
    private func map(_ status: DirectAuthenticationFlow.Status) throws -> AuthTokens {
        switch status {
        case .success(let token):
            return AuthTokens(
                idToken: token.idToken?.rawValue ?? "",
                accessToken: token.accessToken,
                refreshToken: token.refreshToken
            )
        case .mfaRequired:
            throw AuthError.mfaRequired
        case .continuation:
            // Any continuation other than .mfaRequired payload means
            // the IdP wants a second factor we don't support in this
            // Direct-Auth bootstrap. Surface as MFA-required so the
            // UI shows the unsupported-flow copy rather than
            // "invalid credentials".
            throw AuthError.mfaRequired
        @unknown default:
            throw AuthError.invalidCredentials
        }
    }
}
