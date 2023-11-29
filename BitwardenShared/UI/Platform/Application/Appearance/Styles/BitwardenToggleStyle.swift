import SwiftUI

// MARK: - BitwardenToggleStyle

/// A tinted toggle style.
///
struct BitwardenToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .font(.styleGuide(.body))
            .foregroundColor(Asset.Colors.textPrimary.swiftUIColor)
            .tint(Asset.Colors.primaryBitwarden.swiftUIColor)
    }
}

// MARK: ToggleStyle

extension ToggleStyle where Self == BitwardenToggleStyle {
    /// The style for toggles used in this application.
    static var bitwarden: BitwardenToggleStyle { BitwardenToggleStyle() }
}
