import Foundation

/// Decodes the middle (payload) segment of an OIDC ID-token JWT into
/// `IDTokenClaims`.
///
/// This is pure local string manipulation — NO signature verification.
/// Trust comes from the fact that the token was returned by the Okta
/// SDK over TLS at the end of a Direct-Auth flow; we only parse the
/// claims here. A separate JWKS verification step would belong on the
/// resource-server side, not in the mobile client.
///
/// Throws `AuthError.malformedToken` on any structural problem:
///   - not exactly three `.`-separated segments
///   - middle segment fails base64url decode
///   - decoded bytes don't parse as JSON matching `IDTokenClaims`
///
/// Per the prior lesson, callers must map decode failures to a TYPED
/// AuthError so the Login UI doesn't collapse a post-success parse
/// bug into a misleading "couldn't reach Okta" banner. Throwing
/// `AuthError.malformedToken` directly here keeps the type contract
/// end-to-end.
public enum IDTokenDecoder {
    /// Decode the payload segment of a JWT into `IDTokenClaims`.
    /// `auth_time` is interpreted as seconds-since-1970 (OIDC spec).
    public static func decode(_ idToken: String) throws -> IDTokenClaims {
        let segments = idToken.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else {
            throw AuthError.malformedToken
        }

        let payloadSegment = String(segments[1])
        guard let payloadData = base64urlDecode(payloadSegment) else {
            throw AuthError.malformedToken
        }

        let decoder = JSONDecoder()
        // `auth_time` is a NumericDate (seconds since the Unix epoch)
        // per RFC 7519 / OIDC Core. JSONDecoder's
        // .secondsSince1970 dateDecodingStrategy maps it directly.
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            return try decoder.decode(IDTokenClaims.self, from: payloadData)
        } catch {
            throw AuthError.malformedToken
        }
    }

    /// Base64url-decode per RFC 7515 §2: `-` \u2192 `+`, `_` \u2192 `/`, then
    /// pad to a multiple of 4 with `=`. Returns `nil` on any
    /// structural problem so the caller can throw a single typed
    /// `.malformedToken`.
    private static func base64urlDecode(_ input: String) -> Data? {
        var s = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad to a multiple of 4.
        let remainder = s.count % 4
        if remainder > 0 {
            s.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: s)
    }
}
