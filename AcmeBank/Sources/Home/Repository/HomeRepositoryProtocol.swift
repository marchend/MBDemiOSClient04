import Foundation

/// Protocol seam between `HomeViewModel` and the network layer.
///
/// The production implementation (`BFFHomeRepository`) hits the real
/// BFF over URLSession. Tests and SwiftUI previews inject
/// `StubHomeRepository` to avoid network calls.
public protocol HomeRepositoryProtocol {
    func fetchHome() async throws -> HomeDashboard
}
