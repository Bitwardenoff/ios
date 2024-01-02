import SwiftUI

// MARK: - VaultSettingsView

/// A view that allows users to view their vault settings and folders.
///
struct VaultSettingsView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<Void, VaultSettingsAction, Void>

    // MARK: View

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            vaultSettings
        }
        .scrollView()
        .navigationBar(title: Localizations.vault, titleDisplayMode: .inline)
    }

    // MARK: Private views

    /// The vault settings section.
    private var vaultSettings: some View {
        VStack(spacing: 0) {
            SettingsListItem(Localizations.folders) {
                store.send(.foldersTapped)
            }

            SettingsListItem(Localizations.exportVault) {
                store.send(.exportVaultTapped)
            }

            SettingsListItem(Localizations.importItems, hasDivider: false) {
                store.send(.importItemsTapped)
            } trailingContent: {
                Image(asset: Asset.Images.externalLink2)
                    .resizable()
                    .frame(width: 22, height: 22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    VaultSettingsView(store: Store(processor: StateProcessor(state: ())))
}
