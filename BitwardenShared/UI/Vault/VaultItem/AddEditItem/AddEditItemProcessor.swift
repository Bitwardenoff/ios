import BitwardenSdk
import Foundation

// MARK: - AddEditItemProcessor

/// The processor used to manage state and handle actions for the add item screen.
///
final class AddEditItemProcessor: StateProcessor<CipherItemState, AddEditItemAction, AddEditItemEffect> {
    // MARK: Types

    typealias Services = HasCameraAuthorizationService
        & HasErrorReporter
        & HasVaultRepository

    // MARK: Properties

    /// The `Coordinator` that handles navigation.
    private var coordinator: AnyCoordinator<VaultItemRoute>

    /// The services required by this processor.
    private let services: Services

    // MARK: Initialization

    /// Creates a new `AddEditItemProcessor`.
    ///
    /// - Parameters:
    ///   - coordinator: The `Coordinator` that handles navigation.
    ///   - services: The services required by this processor.
    ///   - state: The initial state for the processor.
    ///
    init(
        coordinator: AnyCoordinator<VaultItemRoute>,
        services: Services,
        state: CipherItemState
    ) {
        self.coordinator = coordinator
        self.services = services
        super.init(state: state)
    }

    // MARK: Methods

    override func perform(_ effect: AddEditItemEffect) async {
        switch effect {
        case .checkPasswordPressed:
            await checkPassword()
        case .savePressed:
            await saveItem()
        case .setupTotpPressed:
            await setupTotp()
        }
    }

    override func receive(_ action: AddEditItemAction) { // swiftlint:disable:this function_body_length
        switch action {
        case .dismissPressed:
            coordinator.navigate(to: .dismiss)
        case let .favoriteChanged(newValue):
            state.isFavoriteOn = newValue
        case let .folderChanged(newValue):
            state.folder = newValue
        case .generatePasswordPressed:
            if state.loginState.password.isEmpty {
                coordinator.navigate(to: .generator(.password), context: self)
            } else {
                presentReplacementAlert(for: .password)
            }
        case .generateUsernamePressed:
            if state.loginState.username.isEmpty {
                let first = state.loginState.uris.first?.uri ?? ""
                let uri = URL(string: first)
                let emailWebsite = uri?.sanitized.host
                coordinator.navigate(to: .generator(.username, emailWebsite: emailWebsite), context: self)
            } else {
                presentReplacementAlert(for: .username)
            }
        case let .masterPasswordRePromptChanged(newValue):
            state.isMasterPasswordRePromptOn = newValue
        case .morePressed:
            // TODO: BIT-1131 Open item menu
            print("more pressed")
        case let .nameChanged(newValue):
            state.name = newValue
        case .newCustomFieldPressed:
            presentCustomFieldAlert()
        case .newUriPressed:
            // TODO: BIT-901 Add a new blank URI field
            break
        case let .notesChanged(newValue):
            state.notes = newValue
        case let .ownerChanged(newValue):
            state.owner = newValue
        case let .passwordChanged(newValue):
            state.loginState.password = newValue
        case let .togglePasswordVisibilityChanged(newValue):
            state.loginState.isPasswordVisible = newValue
        case let .typeChanged(newValue):
            state.type = newValue
        case let .uriChanged(newValue, index: index):
            guard state.loginState.uris.count > index else { return }
            let uri = state.loginState.uris[index]
            state.loginState.uris[index] = .init(match: uri.match, uri: newValue)
        case .uriSettingsPressed:
            presentUriSettingsAlert()
        case let .usernameChanged(newValue):
            state.loginState.username = newValue
        }
    }

    // MARK: Private Methods

    /// Checks the password currently stored in `state`.
    ///
    private func checkPassword() async {
        coordinator.showLoadingOverlay(title: Localizations.checkingPassword)
        defer { coordinator.hideLoadingOverlay() }

        do {
            // TODO: BIT-369 Use the api to check the password
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let alert = Alert(
                title: Localizations.passwordExposed(9_659_365),
                message: nil,
                alertActions: [
                    AlertAction(
                        title: Localizations.ok,
                        style: .default
                    ),
                ]
            )
            coordinator.navigate(to: .alert(alert))
        } catch {
            services.errorReporter.log(error: error)
        }
    }

    /// Builds an alert for creating a new custom field and then routes the coordinator
    /// to the `.alert` route.
    ///
    private func presentCustomFieldAlert() {
        // TODO: BIT-368 Navigate to an `.alert` route with the custom field alert
    }

    /// Builds and navigates ot an alert for overwriting an existing value for the specified type.
    ///
    /// - Parameter type: The `GeneratorType` that is being overwritten.
    ///
    private func presentReplacementAlert(for type: GeneratorType) {
        let title: String
        switch type {
        case .password:
            title = Localizations.passwordOverrideAlert
        case .username:
            title = Localizations.areYouSureYouWantToOverwriteTheCurrentUsername
        }

        let alert = Alert(
            title: title,
            message: nil,
            alertActions: [
                AlertAction(title: Localizations.no, style: .default),
                AlertAction(
                    title: Localizations.yes,
                    style: .default,
                    handler: { [weak self] _ in
                        self?.coordinator.navigate(to: .generator(type), context: self)
                    }
                ),
            ]
        )
        coordinator.navigate(to: .alert(alert))
    }

    /// Builds an alert for changing the settings for a uri item and then routes
    /// the coordinator to the `.alert` route.
    ///
    private func presentUriSettingsAlert() {
        // TODO: BIT-901 Navigate to an `.alert` route with the uri settings alert
    }

    /// Saves the item currently stored in `state`.
    ///
    private func saveItem() async {
        coordinator.showLoadingOverlay(title: Localizations.saving)
        defer { coordinator.hideLoadingOverlay() }
        do {
            switch state.configuration {
            case .add:
                try await addItem()
            case let .existing(cipherView):
                try await updateItem(cipherView: cipherView)
            }
        } catch {
            services.errorReporter.log(error: error)
        }
    }

    /// Adds the item currently in `state`.
    ///
    private func addItem() async throws {
        try await services.vaultRepository.addCipher(state.newCipherView())
        coordinator.hideLoadingOverlay()
        coordinator.navigate(to: .dismiss)
    }

    /// Updates the item currently in `state`.
    ///
    private func updateItem(cipherView: CipherView) async throws {
        try await services.vaultRepository.updateCipher(cipherView.updatedView(with: state))
        coordinator.hideLoadingOverlay()
        coordinator.navigate(to: .dismiss)
    }

    /// Kicks off the TOTP setup flow.
    ///
    private func setupTotp() async {
        let status = await services.cameraAuthorizationService.checkStatusOrRequestCameraAuthorization()
        if status == .authorized {
            coordinator.navigate(to: .setupTotpCamera)
        } else {
            coordinator.navigate(to: .setupTotpManual)
        }
    }
}

extension AddEditItemProcessor: GeneratorCoordinatorDelegate {
    func didCancelGenerator() {
        coordinator.navigate(to: .dismiss)
    }

    func didCompleteGenerator(for type: GeneratorType, with value: String) {
        switch type {
        case .password:
            state.loginState.password = value
        case .username:
            state.loginState.username = value
        }
        coordinator.navigate(to: .dismiss)
    }
}
