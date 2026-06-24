import SwiftUI

/// Acme Bank type-scale presets added as static members of `Font`.
/// All entries use `Font.system` with a `TextStyle` so Dynamic Type scales them.
extension Font {
    /// Large screen title — bold, scales with `.largeTitle`
    static let titleLarge: Font = .system(.largeTitle, design: .default, weight: .bold)

    /// Default body copy — regular weight, scales with `.body`
    static let bodyRegular: Font = .system(.body, design: .default, weight: .regular)

    /// Small caption / label — regular weight, scales with `.caption`
    static let labelSmall: Font = .system(.caption, design: .default, weight: .regular)
}
