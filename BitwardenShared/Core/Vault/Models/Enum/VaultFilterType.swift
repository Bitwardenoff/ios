import BitwardenSdk

// MARK: - VaultFilterType

/// An enum that describes the options for filtering the user's vault.
///
public enum VaultFilterType: Equatable, Hashable {
    /// Show my and all organization vaults in the vault list.
    case allVaults

    /// Only show my vaults in the vault list.
    case myVault

    /// Only show the vault items for a specific organization.
    case organization(Organization)

    /// The title of the filter, as shown in the vault list.
    var filterTitle: String {
        switch self {
        case .allVaults:
            "\(Localizations.vaults): \(Localizations.all)"
        case .myVault:
            "\(Localizations.vault): \(Localizations.myVault)"
        case let .organization(organization):
            "\(Localizations.vault): \(organization.name)"
        }
    }

    /// The title of the filter, as shown in the menu to select a filter.
    var title: String {
        switch self {
        case .allVaults:
            Localizations.allVaults
        case .myVault:
            Localizations.myVault
        case let .organization(organization):
            organization.name
        }
    }
}

extension VaultFilterType {
    /// A filter to determine if a `CipherView` should be included in the vault list with the
    /// current filter.
    ///
    /// - Parameter cipher: The `CipherView` to determine if it should be in the vault list.
    /// - Returns: Whether the cipher should be displayed in the vault list.
    ///
    func cipherFilter(_ cipher: CipherView) -> Bool {
        switch self {
        case .allVaults:
            true
        case .myVault:
            cipher.organizationId == nil
        case let .organization(organization):
            cipher.organizationId == organization.id
        }
    }

    /// A filter to determine if a `CollectionView` should be included in the vault list with the
    /// current filter.
    ///
    /// - Parameter collection: The `CollectionView` to determine if it should be in the vault list.
    /// - Returns: Whether the collection should be displayed in the vault list.
    ///
    func collectionFilter(_ collection: CollectionView) -> Bool {
        switch self {
        case .allVaults:
            true
        case .myVault:
            false
        case let .organization(organization):
            collection.organizationId == organization.id
        }
    }

    /// A filter to determine if a `VaultListItem` should be included in the vault list with the
    /// current filter. Filters out any empty folders on the my vault and organization vault filters.
    ///
    /// - Parameter item: The `VaultListItem` to determine if it should be in the vault list.
    /// - Returns: Whether the item should be displayed in the vault list.
    ///
    func folderFilter(_ item: VaultListItem) -> Bool {
        switch (item.itemType, self) {
        case (let .group(_, cipherCount), .myVault),
             (let .group(_, cipherCount), .organization):
            cipherCount > 0
        default:
            true
        }
    }
}

// MARK: - Identifiable

extension VaultFilterType: Identifiable {
    public var id: String {
        title
    }
}
