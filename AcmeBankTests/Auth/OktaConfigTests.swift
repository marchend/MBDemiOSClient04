import XCTest
@testable import AcmeBank

final class OktaConfigTests: XCTestCase {
    // MARK: - Fixtures

    /// All four keys set to realistic, well-formed values.
    private let validInfo: [String: Any] = [
        "OKTA_ISSUER":       "https://acmebank.okta.com/oauth2/default",
        "OKTA_CLIENT_ID":    "0oa1abcDEFghijKLM5d7",
        "OKTA_REDIRECT_URI": "com.acmebank.mobile:/callback",
        "OKTA_SCOPES":       "openid profile email offline_access"
    ]

    /// All four keys set to the sentinel strings the inject script
    /// writes when the matching env var is unset.
    private let allSentinelInfo: [String: Any] = [
        "OKTA_ISSUER":       "__OKTA_ISSUER_UNSET__",
        "OKTA_CLIENT_ID":    "__OKTA_CLIENT_ID_UNSET__",
        "OKTA_REDIRECT_URI": "__OKTA_REDIRECT_URI_UNSET__",
        "OKTA_SCOPES":       "__OKTA_SCOPES_UNSET__"
    ]

    // MARK: - Happy path

    func test_load_withAllValidValues_returnsConfigured() {
        let result = OktaConfig.load(from: validInfo)

        guard case let .configured(issuer, clientId, redirectUri, scopes) = result else {
            return XCTFail("Expected .configured, got \(result)")
        }
        XCTAssertEqual(issuer.absoluteString, "https://acmebank.okta.com/oauth2/default")
        XCTAssertEqual(clientId, "0oa1abcDEFghijKLM5d7")
        XCTAssertEqual(redirectUri.absoluteString, "com.acmebank.mobile:/callback")
        XCTAssertEqual(scopes, ["openid", "profile", "email", "offline_access"])
    }

    // MARK: - All sentinels

    func test_load_withAllSentinels_returnsNotConfigured_namingAllKeys() {
        let result = OktaConfig.load(from: allSentinelInfo)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_ISSUER"),       "reason missing OKTA_ISSUER: \(reason)")
        XCTAssertTrue(reason.contains("OKTA_CLIENT_ID"),    "reason missing OKTA_CLIENT_ID: \(reason)")
        XCTAssertTrue(reason.contains("OKTA_REDIRECT_URI"), "reason missing OKTA_REDIRECT_URI: \(reason)")
        XCTAssertTrue(reason.contains("OKTA_SCOPES"),       "reason missing OKTA_SCOPES: \(reason)")
    }

    // MARK: - Partial missing

    func test_load_withOneSentinel_returnsNotConfigured_namingOnlyThatKey() {
        var info = validInfo
        info["OKTA_CLIENT_ID"] = "__OKTA_CLIENT_ID_UNSET__"

        let result = OktaConfig.load(from: info)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_CLIENT_ID"),
                      "reason should name OKTA_CLIENT_ID: \(reason)")
        XCTAssertFalse(reason.contains("OKTA_ISSUER"),
                       "reason should NOT name OKTA_ISSUER: \(reason)")
        XCTAssertFalse(reason.contains("OKTA_REDIRECT_URI"),
                       "reason should NOT name OKTA_REDIRECT_URI: \(reason)")
        XCTAssertFalse(reason.contains("OKTA_SCOPES"),
                       "reason should NOT name OKTA_SCOPES: \(reason)")
    }

    func test_load_withMissingKey_treatsAbsenceAsUnset() {
        var info = validInfo
        info.removeValue(forKey: "OKTA_REDIRECT_URI")

        let result = OktaConfig.load(from: info)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_REDIRECT_URI"),
                      "reason should name OKTA_REDIRECT_URI: \(reason)")
    }

    func test_load_withEmptyString_treatsAsUnset() {
        var info = validInfo
        info["OKTA_SCOPES"] = ""

        let result = OktaConfig.load(from: info)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_SCOPES"),
                      "reason should name OKTA_SCOPES: \(reason)")
    }

    // MARK: - Malformed URL

    func test_load_withMalformedIssuerURL_returnsNotConfigured() {
        var info = validInfo
        // No scheme → URL(string:) may still produce a URL but with
        // nil scheme; OktaConfig rejects it.
        info["OKTA_ISSUER"] = "not a url"

        let result = OktaConfig.load(from: info)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_ISSUER"),
                      "reason should name OKTA_ISSUER: \(reason)")
    }

    func test_load_withMalformedRedirectURI_returnsNotConfigured() {
        var info = validInfo
        info["OKTA_REDIRECT_URI"] = "no scheme here"

        let result = OktaConfig.load(from: info)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_REDIRECT_URI"),
                      "reason should name OKTA_REDIRECT_URI: \(reason)")
    }

    // MARK: - Edge cases

    func test_load_withEmptyDictionary_returnsNotConfigured_namingAllKeys() {
        let result = OktaConfig.load(from: [:])

        guard case let .notConfigured(reason) = result else {
            return XCTFail("Expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(reason.contains("OKTA_ISSUER"))
        XCTAssertTrue(reason.contains("OKTA_CLIENT_ID"))
        XCTAssertTrue(reason.contains("OKTA_REDIRECT_URI"))
        XCTAssertTrue(reason.contains("OKTA_SCOPES"))
    }
}
