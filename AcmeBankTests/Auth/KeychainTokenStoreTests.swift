import XCTest
import Security
@testable import AcmeBank

/// Tests for `KeychainTokenStore`.
///
/// Each test constructs a store with a UNIQUE per-test service prefix
/// so parallel runs don't collide on the shared simulator keychain.
/// EVERY `SecItem*` query dict in this file (the cleanup helper, the
/// "no-stale-item" probe) sets `kSecUseDataProtectionKeychain: true`
/// — the simulator test host uses the data-protection keychain and
/// without that key `SecItem*` calls return `errSecMissingEntitlement`
/// (-34018) and the whole bundle goes red.
final class KeychainTokenStoreTests: XCTestCase {
    private var idService: String!
    private var accessService: String!
    private var refreshService: String!
    private var store: KeychainTokenStore!

    override func setUp() {
        super.setUp()
        // Per-test unique prefix — UUID guarantees isolation from
        // both the production constants and any prior test run that
        // didn't clean up.
        let prefix = "com.acmebank.test.\(UUID().uuidString)"
        idService = "\(prefix).id"
        accessService = "\(prefix).access"
        refreshService = "\(prefix).refresh"
        store = KeychainTokenStore(
            idService: idService,
            accessService: accessService,
            refreshService: refreshService
        )
    }

    override func tearDown() {
        // Defensive cleanup — even though clearAll covers the happy
        // path, tearDown runs even on test failure paths.
        deleteAll()
        store = nil
        super.tearDown()
    }

    // MARK: - Round trips

    func test_saveAndLoadRefreshToken_roundTrip() throws {
        try store.saveRefreshToken("rt-1")
        XCTAssertEqual(try store.loadRefreshToken(), "rt-1")
    }

    func test_saveIDToken_overwritesExisting() throws {
        // Re-saving the same service is idempotent (delete-then-add).
        try store.saveIDToken("first-id")
        try store.saveIDToken("second-id")
        // ID token has no public loader; assert via a direct
        // SecItemCopyMatching probe that the stored value is the
        // SECOND write, not the first.
        let stored = try Self.directRead(service: idService)
        XCTAssertEqual(stored, "second-id")
    }

    func test_saveAccessToken_overwritesExisting() throws {
        try store.saveAccessToken("first-at")
        try store.saveAccessToken("second-at")
        let stored = try Self.directRead(service: accessService)
        XCTAssertEqual(stored, "second-at")
    }

    func test_saveRefreshToken_overwritesExisting() throws {
        try store.saveRefreshToken("first-rt")
        try store.saveRefreshToken("second-rt")
        XCTAssertEqual(try store.loadRefreshToken(), "second-rt")
    }

    // MARK: - clearAll

    func test_clearAll_removesAllThreeTokens() throws {
        try store.saveIDToken("id")
        try store.saveAccessToken("at")
        try store.saveRefreshToken("rt")

        try store.clearAll()

        XCTAssertNil(try Self.directRead(service: idService))
        XCTAssertNil(try Self.directRead(service: accessService))
        XCTAssertNil(try Self.directRead(service: refreshService))
        // The public loader path also returns nil.
        XCTAssertNil(try store.loadRefreshToken())
    }

    func test_loadRefreshToken_whenAbsent_returnsNil() throws {
        // Pristine store; no prior save.
        XCTAssertNil(try store.loadRefreshToken())
    }

    func test_clearAll_onPristineStore_doesNotThrow() {
        // Idempotent: deleting items that were never added is fine.
        XCTAssertNoThrow(try store.clearAll())
    }

    // MARK: - Probe helpers

    /// Read the raw stored string for a service. Returns nil if the
    /// item doesn't exist. Includes `kSecUseDataProtectionKeychain`
    /// per the bundle-wide rule.
    private static func directRead(service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String:                     kSecClassGenericPassword,
            kSecAttrService as String:               service,
            kSecAttrAccount as String:               "acmebank",
            kSecReturnData as String:                true,
            kSecMatchLimit as String:                kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "SecItemCopyMatching failed"]
            )
        }
    }

    /// Wipe any items this test may have left behind. Tolerates
    /// `errSecItemNotFound`.
    private func deleteAll() {
        for service in [idService, accessService, refreshService] {
            guard let service = service else { continue }
            let query: [String: Any] = [
                kSecClass as String:                     kSecClassGenericPassword,
                kSecAttrService as String:               service,
                kSecAttrAccount as String:               "acmebank",
                kSecUseDataProtectionKeychain as String: true
            ]
            _ = SecItemDelete(query as CFDictionary)
        }
    }
}
