import SwiftUI

/// Bootstrap placeholder screen.
/// Future PRs will replace this with RootView → LoginCoordinator / TabBarCoordinator.
struct ContentView: View {
    var body: some View {
        Text("AcmeBank")
            .font(.largeTitle)
            .fontWeight(.bold)
            .accessibilityIdentifier("acmeBankLabel")
    }
}

#Preview {
    ContentView()
}
