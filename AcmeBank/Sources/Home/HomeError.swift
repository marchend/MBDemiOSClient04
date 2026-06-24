import Foundation

/// Errors surfaced by the Home data layer.
///
/// Deliberately closed and small so `HomeViewModel` can map each case
/// to a single user-facing action (sign-out vs retry).
public enum HomeError: Error, Equatable {
    /// The server returned HTTP 401 — the session token has expired or
    /// been revoked. The ViewModel should sign the user out.
    case unauthorized

    /// Any non-401 HTTP error, network failure, or decoding error.
    /// The wrapped `Error` carries the underlying cause for logging.
    case networkFailure(Error)

    // MARK: - Equatable

    public static func == (lhs: HomeError, rhs: HomeError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized):
            return true
        case (.networkFailure, .networkFailure):
            // Two network failures are considered equal for testing
            // purposes regardless of their wrapped cause.
            return true
        default:
            return false
        }
    }
}
