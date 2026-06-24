import Foundation

/// Production `HomeRepositoryProtocol` implementation that fetches
/// `GET /v1/home` from the Acme Bank BFF.
///
/// - Reads `API_BASE_URL` from `Bundle.main.infoDictionary`. Missing
///   or sentinel values are treated as a network failure (not a hard
///   crash) so the app degrades gracefully when not configured.
/// - Attaches `Authorization: Bearer <accessToken>` from the supplied
///   `UserSession`.
/// - HTTP 401 → `HomeError.unauthorized`
/// - All other non-2xx / network / decoding errors →
///   `HomeError.networkFailure`
///
/// JSON decoding uses `.convertFromSnakeCase` + `.iso8601` date
/// strategy so the BFF's snake_case field names map automatically to
/// the Swift model's camelCase properties.
public final class BFFHomeRepository: HomeRepositoryProtocol {

    private let session: UserSession
    private let urlSession: URLSession
    private let baseURL: String?

    /// Production initializer. Reads `API_BASE_URL` from the main
    /// bundle at call time (not init time) so tests can override the
    /// bundle injection independently of construction.
    public init(session: UserSession, urlSession: URLSession = .shared) {
        self.session = session
        self.urlSession = urlSession
        self.baseURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String
    }

    /// Seam for tests: inject a custom base URL and URLSession.
    internal init(session: UserSession, baseURL: String?, urlSession: URLSession) {
        self.session = session
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // MARK: - HomeRepositoryProtocol

    public func fetchHome() async throws -> HomeDashboard {
        let base = baseURL ?? ""

        // Treat a missing, empty, or sentinel base URL as a
        // configuration failure rather than attempting a request to
        // an unusable host.
        guard !base.isEmpty,
              !base.contains("__API_BASE_URL_UNSET__"),
              let url = URL(string: "\(base)/v1/home")
        else {
            throw HomeError.networkFailure(
                URLError(.badURL,
                         userInfo: [NSURLErrorFailingURLStringErrorKey:
                                        "\(base)/v1/home"])
            )
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessToken)",
                         forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw HomeError.networkFailure(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HomeError.networkFailure(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw HomeError.unauthorized
        default:
            throw HomeError.networkFailure(
                URLError(.badServerResponse,
                         userInfo: [NSURLErrorFailingURLStringErrorKey:
                                        url.absoluteString,
                                    "HTTPStatusCode": http.statusCode])
            )
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(HomeDashboard.self, from: data)
        } catch {
            throw HomeError.networkFailure(error)
        }
    }
}
