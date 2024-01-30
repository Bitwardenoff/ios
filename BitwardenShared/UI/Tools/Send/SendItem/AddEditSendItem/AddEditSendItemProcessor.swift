import BitwardenSdk
import Foundation

// MARK: - AddEditSendItemProcessor

/// The processor used to manage state and handle actions for the add/edit send item screen.
///
class AddEditSendItemProcessor: // swiftlint:disable:this type_body_length
    StateProcessor<AddEditSendItemState, AddEditSendItemAction, AddEditSendItemEffect> {
    // MARK: Types

    typealias Services = HasAuthRepository
        & HasErrorReporter
        & HasPasteboardService
        & HasPolicyService
        & HasSendRepository

    // MARK: Private Properties

    /// A block to execute the next time the toast is cleared. This value is cleared once the block
    /// is executed once.
    private var onNextToastClear: (() -> Void)?

    // MARK: Properties

    /// The `Coordinator` that handles navigation for this processor.
    let coordinator: any Coordinator<SendItemRoute, AuthAction>

    /// The services required by this processor.
    let services: Services

    // MARK: Initialization

    /// Creates a new `AddEditSendItemProcessor`.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator that handles navigation for this processor.
    ///   - services: The services required by this processor.
    ///   - state: The initial state of this processor.
    ///
    init(
        coordinator: any Coordinator<SendItemRoute, AuthAction>,
        services: Services,
        state: AddEditSendItemState
    ) {
        self.coordinator = coordinator
        self.services = services
        super.init(state: state)
    }

    // MARK: Methods

    override func perform(_ effect: AddEditSendItemEffect) async {
        switch effect {
        case .copyLinkPressed:
            guard let sendView = state.originalSendView else { return }
            await copyLink(to: sendView)
        case .deletePressed:
            guard let sendView = state.originalSendView else { return }
            let alert = Alert.confirmation(title: Localizations.areYouSureDeleteSend) { [weak self] in
                await self?.deleteSend(sendView)
            }
            coordinator.showAlert(alert)
        case .loadData:
            await loadData()
        case let .profileSwitcher(profileEffect):
            guard case var .shareExtension(profileSwitcherState) = state.mode else { return }
            switch profileEffect {
            case let .rowAppeared(rowType):
                guard profileSwitcherState.shouldSetAccessibilityFocus(for: rowType) == true else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    profileSwitcherState.hasSetAccessibilityFocus = true
                    self.state.mode = .shareExtension(profileSwitcherState)
                }
            }
        case .removePassword:
            guard let sendView = state.originalSendView else { return }
            let alert = Alert.confirmation(title: Localizations.areYouSureRemoveSendPassword) { [weak self] in
                await self?.removePassword(sendView)
            }
            coordinator.showAlert(alert)
        case .savePressed:
            await saveSendItem()
        case .shareLinkPressed:
            guard let sendView = state.originalSendView else { return }
            await shareSaveURL(sendView)
        }
    }

    override func receive(_ action: AddEditSendItemAction) {
        switch action {
        case .chooseFilePressed:
            presentFileSelectionAlert()
        case .clearExpirationDatePressed:
            state.customExpirationDate = nil
        case let .customDeletionDateChanged(newValue):
            state.customDeletionDate = newValue
        case let .customExpirationDateChanged(newValue):
            state.customExpirationDate = newValue
        case let .deactivateThisSendChanged(newValue):
            state.isDeactivateThisSendOn = newValue
        case let .deletionDateChanged(newValue):
            state.deletionDate = newValue
        case let .expirationDateChanged(newValue):
            state.expirationDate = newValue
        case .dismissPressed:
            coordinator.navigate(to: .cancel)
        case let .hideMyEmailChanged(newValue):
            state.isHideMyEmailOn = newValue
        case let .hideTextByDefaultChanged(newValue):
            state.isHideTextByDefaultOn = newValue
        case .optionsPressed:
            state.isOptionsExpanded.toggle()
        case let .passwordChanged(newValue):
            state.password = newValue
        case let .passwordVisibleChanged(newValue):
            state.isPasswordVisible = newValue
        case let .profileSwitcherAction(profileAction):
            handle(profileAction)
        case let .maximumAccessCountChanged(newValue):
            state.maximumAccessCount = newValue
        case let .nameChanged(newValue):
            state.name = newValue
        case let .notesChanged(newValue):
            state.notes = newValue
        case let .textChanged(newValue):
            state.text = newValue
        case let .toastShown(toast):
            state.toast = toast
            if toast == nil {
                onNextToastClear?()
                onNextToastClear = nil
            }
        case let .typeChanged(newValue):
            updateType(newValue)
        }
    }

    // MARK: Private Methods

    /// Copies the share link for the provided send.
    ///
    /// - Parameter sendView: The send to copy the link to.
    ///
    private func copyLink(to sendView: SendView) async {
        guard let url = try? await services.sendRepository.shareURL(for: sendView) else { return }

        services.pasteboardService.copy(url.absoluteString)
        state.toast = Toast(text: Localizations.valueHasBeenCopied(Localizations.sendLink))
    }

    /// Deletes the provided send.
    ///
    /// - Parameter sendView: The send to be deleted.
    ///
    private func deleteSend(_ sendView: SendView) async {
        coordinator.showLoadingOverlay(LoadingOverlayState(title: Localizations.deleting))
        do {
            try await services.sendRepository.deleteSend(sendView)
            coordinator.hideLoadingOverlay()
            coordinator.navigate(to: .deleted)
        } catch {
            let alert = Alert.networkResponseError(error) { [weak self] in
                await self?.deleteSend(sendView)
            }
            coordinator.hideLoadingOverlay()
            coordinator.showAlert(alert)
        }
    }

    /// Load any initial data for the view.
    ///
    private func loadData() async {
        state.isSendDisabled = await services.policyService.policyAppliesToUser(.disableSend)
        state.isSendHideEmailDisabled = await services.policyService.isSendHideEmailDisabledByPolicy()
        await refreshProfileState()
    }

    /// Handles a tap of an account in the profile switcher
    /// - Parameter selectedAccount: The `ProfileSwitcherItem` selected by the user.
    ///
    private func didTapProfileSwitcherItem(
        _ selectedAccount: ProfileSwitcherItem,
        switcherState: ProfileSwitcherState
    ) {
        var newSwitcherState = switcherState
        newSwitcherState.isVisible = false
        defer { state.mode = .shareExtension(newSwitcherState) }
        guard selectedAccount.userId != newSwitcherState.activeAccountId else { return }
        Task {
            await coordinator.handleEvent(
                .switchAccount(
                    isAutomatic: false,
                    userId: selectedAccount.userId
                )
            )
        }
    }

    private func handle(_ profileAction: ProfileSwitcherAction) {
        guard case var .shareExtension(switcherState) = state.mode else { return }
        switch profileAction {
        case .accountLongPressed,
             .addAccountPressed:
            // No-Op for the extension
            break
        case let .accountPressed(account):
            didTapProfileSwitcherItem(account, switcherState: switcherState)
        case .backgroundPressed:
            switcherState.isVisible = false
            state.mode = .shareExtension(switcherState)
        case let .requestedProfileSwitcher(visible: isVisible):
            switcherState.isVisible = isVisible
            state.mode = .shareExtension(switcherState)
        case let .scrollOffsetChanged(newOffset):
            switcherState.scrollOffset = newOffset
            state.mode = .shareExtension(switcherState)
        }
    }

    /// Presents the file selection alert.
    ///
    private func presentFileSelectionAlert() {
        let alert = Alert.fileSelectionOptions { [weak self] route in
            guard let self else { return }
            coordinator.navigate(to: .fileSelection(route), context: self)
        }
        coordinator.showAlert(alert)
    }

    /// Configures a profile switcher state with the current account and alternates.
    ///
    private func refreshProfileState() async {
        guard case let .shareExtension(switcherState) = state.mode else { return }
        let newSwitcherState = await services.authRepository.getProfilesState(
            isVisible: switcherState.isVisible,
            shouldAlwaysHideAddAccount: true
        )
        state.mode = .shareExtension(newSwitcherState)
    }

    /// Removes the password from the provided send.
    ///
    /// - Parameter sendView: The send to remove the password from.
    ///
    private func removePassword(_ sendView: SendView) async {
        coordinator.showLoadingOverlay(LoadingOverlayState(title: Localizations.removingSendPassword))
        do {
            let newSend = try await services.sendRepository.removePassword(from: sendView)
            var newState = AddEditSendItemState(sendView: newSend, hasPremium: state.hasPremium)
            newState.isOptionsExpanded = state.isOptionsExpanded
            state = newState

            coordinator.hideLoadingOverlay()
            state.toast = Toast(text: Localizations.sendPasswordRemoved)
        } catch {
            let alert = Alert.networkResponseError(error) { [weak self] in
                await self?.removePassword(sendView)
            }
            coordinator.hideLoadingOverlay()
            coordinator.showAlert(alert)
        }
    }

    /// Saves the current send item.
    ///
    private func saveSendItem() async {
        guard await validateSend() else { return }

        coordinator.showLoadingOverlay(LoadingOverlayState(title: Localizations.saving))
        defer { coordinator.hideLoadingOverlay() }

        let sendView = state.newSendView()
        do {
            let newSendView: SendView
            switch state.mode {
            case .add, .shareExtension:
                switch state.type {
                case .file:
                    guard let fileData = state.fileData else { return }
                    newSendView = try await services.sendRepository.addFileSend(sendView, data: fileData)
                case .text:
                    newSendView = try await services.sendRepository.addTextSend(sendView)
                }
            case .edit:
                newSendView = try await services.sendRepository.updateSend(sendView)
            }
            coordinator.hideLoadingOverlay()
            switch state.mode {
            case .add, .edit:
                coordinator.navigate(to: .complete(newSendView))
            case .shareExtension:
                onNextToastClear = { [weak self] in
                    self?.coordinator.navigate(to: .complete(newSendView))
                }
                await copyLink(to: newSendView)
            }
        } catch {
            coordinator.showAlert(.networkResponseError(error) { [weak self] in
                await self?.saveSendItem()
            })
        }
    }

    /// Navigates to the `.share` route for the provided send view.
    ///
    /// - Parameter sendView: The send that is being shared.
    ///
    private func shareSaveURL(_ sendView: SendView) async {
        guard let url = try? await services.sendRepository.shareURL(for: sendView)
        else { return }

        coordinator.navigate(to: .share(url: url))
    }

    /// Attempts to update the send type. If the new value requires premium access and the active
    /// account does not have premium access, this method will display an alert informing the user
    /// that they do not have access to this feature.
    ///
    /// - Parameter newValue: The new value for the Send's type that will be attempted to be set.
    ///
    private func updateType(_ newValue: SendType) {
        guard !newValue.requiresPremium || state.hasPremium else {
            coordinator.showAlert(.defaultAlert(title: Localizations.sendFilePremiumRequired))
            return
        }
        state.type = newValue
    }

    /// Validates that the content in the state comprises a valid send. If any validation issue is
    /// found, an alert will be presented.
    ///
    /// - Returns: A flag indicating if the state holds valid information for creating a send.
    ///
    private func validateSend() async -> Bool {
        guard !state.name.isEmpty else {
            let alert = Alert.validationFieldRequired(fieldName: Localizations.name)
            coordinator.showAlert(alert)
            return false
        }

        // Only perform further checks for file sends.
        guard state.type == .file else { return true }

        let hasPremium = try? await services.sendRepository.doesActiveAccountHavePremium()
        guard hasPremium ?? false else {
            let alert = Alert.defaultAlert(
                message: Localizations.sendFilePremiumRequired
            )
            coordinator.showAlert(alert)
            return false
        }

        let isEmailVerified = try? await services.sendRepository.doesActiveAccountHaveVerifiedEmail()
        guard isEmailVerified ?? false else {
            let alert = Alert.defaultAlert(
                message: Localizations.sendFileEmailVerificationRequired
            )
            coordinator.showAlert(alert)
            return false
        }

        // Only perform further checks when adding a new file send.
        guard state.mode == .add else { return true }

        guard let fileData = state.fileData, state.fileName != nil else {
            let alert = Alert.validationFieldRequired(fieldName: Localizations.file)
            coordinator.showAlert(alert)
            return false
        }

        guard fileData.count <= Constants.maxFileSizeBytes else {
            let alert = Alert.defaultAlert(
                title: Localizations.anErrorHasOccurred,
                message: Localizations.maxFileSize
            )
            coordinator.showAlert(alert)
            return false
        }

        return true
    }
}

// MARK: - AddEditSendItemProcessor:FileSelectionDelegate

extension AddEditSendItemProcessor: FileSelectionDelegate {
    func fileSelectionCompleted(fileName: String, data: Data) {
        state.fileName = fileName
        state.fileData = data
    }
}
