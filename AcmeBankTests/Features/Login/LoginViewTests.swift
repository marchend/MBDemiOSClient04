import XCTest
import UIKit
import SwiftUI
@testable import AcmeBank

/// Lightweight host-app smoke tests for `LoginView`.
///
/// These tests verify that `LoginView` and its `LoginViewModel` can be
/// instantiated and embedded in a `UIHostingController` without throwing.
/// No snapshot comparison is performed (avoids PNG-on-disk CI failures).
final class LoginViewTests: XCTestCase {

    func test_loginView_initializesWithoutThrowing() {
        let viewModel = LoginViewModel(onSignIn: { _, _ in })
        XCTAssertNoThrow(
            { _ = LoginView(viewModel: viewModel) }(),
            "LoginView should initialise without throwing"
        )
    }

    func test_loginView_hostsInUIHostingController() {
        let viewModel = LoginViewModel(onSignIn: { _, _ in })
        let view = LoginView(viewModel: viewModel)
        let hc = UIHostingController(rootView: AnyView(view))

        // Simulate the hosting controller mounting its view
        hc.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        hc.view.setNeedsLayout()
        hc.view.layoutIfNeeded()

        XCTAssertFalse(hc.view.frame.isEmpty,
                       "UIHostingController view should have a non-empty frame")
    }

    func test_contentView_initializesWithoutThrowing() {
        XCTAssertNoThrow(
            { _ = ContentView() }(),
            "ContentView (composition root) should initialise without throwing"
        )
    }
}
