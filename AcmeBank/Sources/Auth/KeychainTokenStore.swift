import Foundation
import Security

/// Protocol seam for token persistence. The production implementation
/// is `KeychainTokenStore`; tests and the (later) SessionRestorer may
/// substitute an in-memory fake.
///
/// Methods are intentionally separate per token kind so each item gets
/// its own `kSecAttrService` and can be cleared independently. ID +
/// access tokens are short-lived and could in principle be re-fetched
/// via refresh; we still persist them for offline rehydration in PR 4.
public protocol TokenStore {
    func saveIDToken(_ token: String) throws
    func saveAccessToken(_ token: String) throws
    func saveRefreshToken(_ token: String) throws
    func loadRefreshToken() throws -> String?
    func clearAll() throws
}

/// Errors surfaced by `KeychainTokenStore`. Stays internal to the
/// store; `AuthService` (PR 3) catches and treats keychain writes as
/// a best-effort cache, per the prior lesson — a transient
/// `errSecMissingEntitlement` on the simulator must not turn a
/// successful sign-in into a failure.
public enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case dataEncodingFailed
}

/// Data-protection Keychain-backed `TokenStore`. Each token kind lives
/// under its own `kSecAttrService` so updates and deletes touch only
/// the relevant item.
///
/// EVERY query dict sets `kSecUseDataProtectionKeychain: true` — this
/// is mandatory for the `CODE_SIGNING_ALLOWED=NO` simulator
/// environment CI uses; without it `SecItemAdd` returns
/// `errSecMissingEntitlement` (-34018) and the whole test bundle goes
/// red. (See AGENT.md "Keychain note for future feature agents".)
public final class KeychainTokenStore: TokenStore {
    /// Service strings the production app uses. Tests construct a
    /// store with custom prefixes to isolate per-test items.
    public static let defaultIDService      = "com.acmebank.token.id"
    public static let defaultAccessService  = "com.acmebank.token.access"
    public static let defaultRefreshService = "com.acmebank.token.refresh"

    /// Fixed `kSecAttrAccount` value. The store keys items by service
    /// alone, so account is a stable constant.
    private static let account = "acmebank"

    private let idService: String
    private let accessService: String
    private let refreshService: String

    /// Production initializer uses the `default*Service` constants.
    /// Tests inject distinct prefixes to keep parallel test runs from
    /// colliding on the same shared keychain.
    public init(
        idService: String = KeychainTokenStore.defaultIDService,
        accessService: String = KeychainTokenStore.defaultAccessService,
        refreshService: String = KeychainTokenStore.defaultRefreshService
    ) {
        self.idService = idService
        self.accessService = accessService
        self.refreshService = refreshService
    }

    // MARK: - TokenStore

    public func saveIDToken(_ token: String) throws {
        try save(token, service: idService)
    }

    public func saveAccessToken(_ token: String) throws {
        try save(token, service: accessService)
    }

    public func saveRefreshToken(_ token: String) throws {
        try save(token, service: refreshService)
    }

    public func loadRefreshToken() throws -> String? {
        try load(service: refreshService)
    }

    public func clearAll() throws {
        try delete(service: idService)
        try delete(service: accessService)
        try delete(service: refreshService)
    }

    // MARK: - Primitives

    /// Delete-then-add for idempotency: SecItemUpdate is finicky when
    /// the matching attribute set differs across writes; a clean
    /// delete + add always converges on a single item per service.
    private func save(_ token: String, service: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.dataEncodingFailed
        }
        try delete(service: service) // idempotent — ignores .itemNotFound
        let attrs: [String: Any] = [
            kSecClass as String:                  kSecClassGenericPassword,
            kSecAttrService as String:            service,
            kSecAttrAccount as String:            Self.account,
            kSecValueData as String:              data,
            kSecUseDataProtectionKeychain as String: true
        ]
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func load(service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String:                  kSecClassGenericPassword,
            kSecAttrService as String:            service,
            kSecAttrAccount as String:            Self.account,
            kSecReturnData as String:             true,
            kSecMatchLimit as String:             kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
                return nil
            }
            return s
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func delete(service: String) throws {
        let query: [String: Any] = [
            kSecClass as String:                  kSecClassGenericPassword,
            kSecAttrService as String:            service,
            kSecAttrAccount as String:            Self.account,
            kSecUseDataProtectionKeychain as String: true
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
