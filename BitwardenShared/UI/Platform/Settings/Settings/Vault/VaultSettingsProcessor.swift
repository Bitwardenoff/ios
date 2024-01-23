// MARK: - VaultSettingsProcessor

/// The processor used to manage state and handle actions for the `VaultSettingsView`.
///
final class VaultSettingsProcessor: StateProcessor<VaultSettingsState, VaultSettingsAction, Void> {
    // MARK: Properties

    /// The coordinator used to manage navigation.
    private let coordinator: AnyCoordinator<SettingsRoute>

    // MARK: Initialization

    /// Initializes a new `VaultSettingsProcessor`.
    ///
    /// - Parameter coordinator: The coordinator used to manage navigation.
    ///
    init(
        coordinator: AnyCoordinator<SettingsRoute>,
        state: VaultSettingsState
    ) {
        self.coordinator = coordinator
        super.init(state: state)
    }

    // MARK: Methods

    override func receive(_ action: VaultSettingsAction) {
        switch action {
        case .clearImportItemsUrl:
            state.importItemsUrl = nil
        case .exportVaultTapped:
            coordinator.navigate(to: .exportVault)
        case .foldersTapped:
            coordinator.navigate(to: .folders)
        case .importItemsTapped:
            state.importItemsUrl = ExternalLinksConstants.importItems
        }
    }
}
