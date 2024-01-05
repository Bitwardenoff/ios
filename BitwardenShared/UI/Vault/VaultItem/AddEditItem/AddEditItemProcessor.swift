import BitwardenSdk
import Foundation

// MARK: - AddEditItemProcessor

/// The processor used to manage state and handle actions for the add item screen.
final class AddEditItemProcessor: // swiftlint:disable:this type_body_length
    StateProcessor<AddEditItemState, AddEditItemAction, AddEditItemEffect> {
    // MARK: Types

    typealias Services = HasCameraService
        & HasErrorReporter
        & HasPasteboardService
        & HasTOTPService
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
        state: AddEditItemState
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
        case .copyTotpPressed:
            guard let key = state.loginState.authenticatorKey else { return }
            services.pasteboardService.copy(key)
            state.toast = Toast(text: Localizations.valueHasBeenCopied(Localizations.authenticatorKeyScanner))
        case .fetchCipherOptions:
            await fetchCipherOptions()
        case .savePressed:
            await saveItem()
        case .setupTotpPressed:
            await setupTotp()
        case .deletePressed:
            // TODO: BIT-222
            print("delete pressed")
        }
    }

    override func receive(_ action: AddEditItemAction) { // swiftlint:disable:this function_body_length
        switch action {
        case let .cardFieldChanged(cardFieldAction):
            updateCardState(&state, for: cardFieldAction)
        case let .collectionToggleChanged(newValue, collectionId):
            state.toggleCollection(newValue: newValue, collectionId: collectionId)
        case .dismissPressed:
            coordinator.navigate(to: .dismiss())
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
                let emailWebsite = state.loginState.generatorEmailWebsite
                coordinator.navigate(to: .generator(.username, emailWebsite: emailWebsite), context: self)
            } else {
                presentReplacementAlert(for: .username)
            }
        case let .identityFieldChanged(action):
            updateIdentityState(&state, for: action)
        case let .masterPasswordRePromptChanged(newValue):
            state.isMasterPasswordRePromptOn = newValue
        case let .morePressed(menuAction):
            switch menuAction {
            case .attachments:
                // TODO: BIT-364
                print("attachments")
            case .clone:
                // TODO: BIT-365
                print("clone")
            case .editCollections:
                coordinator.navigate(to: .editCollections(state.cipher))
            case .moveToOrganization:
                coordinator.navigate(to: .moveToOrganization(state.cipher))
            }
        case let .nameChanged(newValue):
            state.name = newValue
        case .newCustomFieldPressed:
            presentCustomFieldAlert()
        case .newUriPressed:
            state.loginState.uris.append(UriState())
        case let .notesChanged(newValue):
            state.notes = newValue
        case let .ownerChanged(newValue):
            state.owner = newValue
        case let .passwordChanged(newValue):
            state.loginState.password = newValue
        case let .removeUriPressed(index):
            guard index < state.loginState.uris.count else { return }
            state.loginState.uris.remove(at: index)
        case let .togglePasswordVisibilityChanged(newValue):
            state.loginState.isPasswordVisible = newValue
        case let .toastShown(newValue):
            state.toast = newValue
        case let .totpKeyChanged(newValue):
            state.loginState.totpKey = (newValue != nil)
                ? TOTPCodeConfig(authenticatorKey: newValue!)
                : nil
        case let .typeChanged(newValue):
            state.type = newValue
        case let .uriChanged(newValue, index: index):
            guard state.loginState.uris.count > index else { return }
            state.loginState.uris[index].uri = newValue
        case let .uriTypeChanged(newValue, index):
            guard index < state.loginState.uris.count else { return }
            state.loginState.uris[index].matchType = newValue
        case let .usernameChanged(newValue):
            state.loginState.username = newValue
        }
    }

    // MARK: Private Methods

    /// Fetches any additional data (e.g. organizations and folders) needed for adding or editing a cipher.
    private func fetchCipherOptions() async {
        do {
            state.collections = try await services.vaultRepository.fetchCollections(includeReadOnly: false)
            state.ownershipOptions = try await services.vaultRepository
                .fetchCipherOwnershipOptions(includePersonal: true)

            let folders = try await services.vaultRepository.fetchFolders()
                .map { DefaultableType<FolderView>.custom($0) }
            state.folders = [.default] + folders
        } catch {
            services.errorReporter.log(error: error)
        }
    }

    /// Receives an `AddEditCardItem` action from the `AddEditCardView` view's store, and updates
    /// the `AddEditCardState`.
    ///
    /// - Parameters:
    ///   - state: The parent `AddEditCardState` to be updated.
    ///   - action: The `AddEditCardItemAction` received.
    private func updateCardState(_ state: inout AddEditItemState, for action: AddEditCardItemAction) {
        switch action {
        case let .brandChanged(brand):
            state.cardItemState.brand = brand
        case let .cardholderNameChanged(name):
            state.cardItemState.cardholderName = name
        case let .cardNumberChanged(number):
            state.cardItemState.cardNumber = number
        case let .cardSecurityCodeChanged(code):
            state.cardItemState.cardSecurityCode = code
        case let .expirationMonthChanged(month):
            state.cardItemState.expirationMonth = month
        case let .expirationYearChanged(year):
            state.cardItemState.expirationYear = year
        case let .toggleCodeVisibilityChanged(isVisible):
            state.cardItemState.isCodeVisible = isVisible
        case let .toggleNumberVisibilityChanged(isVisible):
            state.cardItemState.isNumberVisible = isVisible
        }
    }

    /// Receives an `AddEditIdentityItem` action from the `AddEditIdentityView` view's store, and updates
    /// the `AddEditIdentityState`.
    ///
    /// - Parameters:
    ///   - state: The parent `AddEditItemState` to be updated.
    ///   - action: The `AddEditIdentityItemAction` received.
    private func updateIdentityState(_ state: inout AddEditItemState, for action: AddEditIdentityItemAction) {
        switch action {
        case let .firstNameChanged(firstName):
            state.identityState.firstName = firstName
        case let .middleNameChanged(middleName):
            state.identityState.middleName = middleName
        case let .titleChanged(title):
            state.identityState.title = title
        case let .lastNameChanged(lastName):
            state.identityState.lastName = lastName
        case let .userNameChanged(userName):
            state.identityState.userName = userName
        case let .companyChanged(company):
            state.identityState.company = company
        case let .socialSecurityNumberChanged(ssn):
            state.identityState.socialSecurityNumber = ssn
        case let .passportNumberChanged(passportNumber):
            state.identityState.passportNumber = passportNumber
        case let .licenseNumberChanged(licenseNumber):
            state.identityState.licenseNumber = licenseNumber
        case let .emailChanged(email):
            state.identityState.email = email
        case let .phoneNumberChanged(phoneNumber):
            state.identityState.phone = phoneNumber
        case let .address1Changed(address1):
            state.identityState.address1 = address1
        case let .address2Changed(address2):
            state.identityState.address2 = address2
        case let .address3Changed(address3):
            state.identityState.address3 = address3
        case let .cityOrTownChanged(cityOrTown):
            state.identityState.cityOrTown = cityOrTown
        case let .stateChanged(stateProvince):
            state.identityState.state = stateProvince
        case let .postalCodeChanged(postalCode):
            state.identityState.postalCode = postalCode
        case let .countryChanged(country):
            state.identityState.country = country
        }
    }

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

    /// Builds and navigates to an alert for overwriting an existing value for the specified type.
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
                        let emailWebsite = self?.state.loginState.generatorEmailWebsite
                        self?.coordinator.navigate(to: .generator(type, emailWebsite: emailWebsite), context: self)
                    }
                ),
            ]
        )
        coordinator.navigate(to: .alert(alert))
    }

    /// Saves the item currently stored in `state`.
    ///
    private func saveItem() async {
        guard state.cipher.organizationId == nil || !state.cipher.collectionIds.isEmpty else {
            coordinator.showAlert(
                .defaultAlert(
                    title: Localizations.anErrorHasOccurred,
                    message: Localizations.selectOneCollection
                )
            )
            return
        }

        defer { coordinator.hideLoadingOverlay() }
        do {
            try EmptyInputValidator(fieldName: Localizations.name)
                .validate(input: state.name)
            coordinator.showLoadingOverlay(title: Localizations.saving)
            switch state.configuration {
            case .add:
                try await addItem()
            case let .existing(cipherView):
                try await updateItem(cipherView: cipherView)
            }
        } catch let error as InputValidationError {
            coordinator.showAlert(Alert.inputValidationAlert(error: error))
            return
        } catch {
            coordinator.showAlert(.networkResponseError(error))
            services.errorReporter.log(error: error)
        }
    }

    /// Adds the item currently in `state`.
    ///
    private func addItem() async throws {
        try await services.vaultRepository.addCipher(state.cipher)
        coordinator.hideLoadingOverlay()
        coordinator.navigate(to: .dismiss())
    }

    /// Updates the item currently in `state`.
    ///
    private func updateItem(cipherView: CipherView) async throws {
        try await services.vaultRepository.updateCipher(cipherView.updatedView(with: state))
        coordinator.hideLoadingOverlay()
        coordinator.navigate(to: .dismiss())
    }

    /// Kicks off the TOTP setup flow.
    ///
    private func setupTotp() async {
        let status = await services.cameraService.checkStatusOrRequestCameraAuthorization()
        if status == .authorized {
            await coordinator.navigate(asyncTo: .scanCode, context: self)
        } else {
            coordinator.navigate(to: .setupTotpManual, context: self)
        }
    }
}

extension AddEditItemProcessor: GeneratorCoordinatorDelegate {
    func didCancelGenerator() {
        coordinator.navigate(to: .dismiss())
    }

    func didCompleteGenerator(for type: GeneratorType, with value: String) {
        switch type {
        case .password:
            state.loginState.password = value
        case .username:
            state.loginState.username = value
        }
        coordinator.navigate(to: .dismiss())
    }
}

extension AddEditItemProcessor: AuthenticatorKeyCaptureDelegate {
    func didCompleteCapture(
        _ captureCoordinator: AnyCoordinator<AuthenticatorKeyCaptureRoute>,
        with value: String
    ) {
        let dismissAction = DismissAction(action: { [weak self] in
            self?.parseAuthenticatorKey(value)
        })
        captureCoordinator.navigate(to: .dismiss(dismissAction))
    }

    func parseAuthenticatorKey(_ key: String) {
        do {
            state.loginState.totpKey = try services.totpService.getTOTPConfiguration(key: key)
            state.toast = Toast(text: Localizations.authenticatorKeyAdded)
        } catch {
            coordinator.navigate(to: .alert(.totpScanFailureAlert()))
        }
    }
}
