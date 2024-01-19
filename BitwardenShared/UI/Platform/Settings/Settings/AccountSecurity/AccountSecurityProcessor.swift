import Foundation
import OSLog

// MARK: - AccountSecurityProcessor

/// The processor used to manage state and handle actions for the account security screen.
///
final class AccountSecurityProcessor: StateProcessor<
    AccountSecurityState,
    AccountSecurityAction,
    AccountSecurityEffect
> {
    // MARK: Types

    typealias Services = HasAuthRepository
        & HasBiometricsService
        & HasClientAuth
        & HasErrorReporter
        & HasSettingsRepository
        & HasStateService
        & HasTwoStepLoginService

    // MARK: Private Properties

    /// The `Coordinator` that handles navigation.
    private let coordinator: AnyCoordinator<SettingsRoute>

    /// The services used by this processor.
    private var services: Services

    // MARK: Initialization

    /// Creates a new `AccountSecurityProcessor`.
    ///
    /// - Parameters:
    ///   - coordinator: The `Coordinator` that handles navigation.
    ///   - services: The services used by the processor.
    ///   - state: The initial state of the processor.
    ///
    init(
        coordinator: AnyCoordinator<SettingsRoute>,
        services: Services,
        state: AccountSecurityState
    ) {
        self.coordinator = coordinator
        self.services = services
        super.init(state: state)
    }

    // MARK: Methods

    override func perform(_ effect: AccountSecurityEffect) async {
        switch effect {
        case .accountFingerprintPhrasePressed:
            await showAccountFingerprintPhraseAlert()
        case .loadData:
            await loadData()
        case .lockVault:
            await lockVault()
        case let .toggleUnlockWithBiometrics(isOn):
            await setBioMetricAuth(isOn)
        }
    }

    override func receive(_ action: AccountSecurityAction) {
        switch action {
        case .clearFingerprintPhraseUrl:
            state.fingerprintPhraseUrl = nil
        case .clearTwoStepLoginUrl:
            state.twoStepLoginUrl = nil
        case .deleteAccountPressed:
            coordinator.navigate(to: .deleteAccount)
        case .logout:
            showLogoutConfirmation()
        case let .sessionTimeoutActionChanged(action):
            saveTimeoutActionSetting(action)
        case let .sessionTimeoutValueChanged(newValue):
            state.sessionTimeoutValue = newValue
        case let .setCustomSessionTimeoutValue(newValue):
            state.customSessionTimeoutValue = newValue
        case let .toggleApproveLoginRequestsToggle(isOn):
            state.isApproveLoginRequestsToggleOn = isOn
        case let .toggleUnlockWithPINCode(isOn):
            toggleUnlockWithPIN(isOn)
        case .twoStepLoginPressed:
            showTwoStepLoginAlert()
        }
    }

    // MARK: Private

    /// Loads async data to the state.
    ///
    private func loadData() async {
        state.biometricUnlockStatus = await loadBiometricUnlockPreference()
    }

    /// Loads the state of the user's biometric unlock preferences.
    ///
    /// - Returns: The `BiometricsUnlockStatus` for the user.
    ///
    private func loadBiometricUnlockPreference() async -> BiometricsUnlockStatus {
        do {
            let biometricsStatus = try await services.biometricsService.getBiometricUnlockStatus()
            return biometricsStatus
        } catch {
            Logger.application.debug("Error loading biometric preferences: \(error)")
            return .notAvailable
        }
    }

    /// Locks the user's vault
    ///
    private func lockVault() async {
        do {
            let account = try await services.stateService.getActiveAccount()
            await services.settingsRepository.lockVault(userId: account.profile.userId)
            coordinator.navigate(to: .lockVault(account: account))
        } catch {
            coordinator.navigate(to: .logout)
            services.errorReporter.log(error: error)
        }
    }

    /// Saves the user's session timeout action.
    ///
    /// - Parameter action: The action to perform on session timeout.
    ///
    private func saveTimeoutActionSetting(_ action: SessionTimeoutAction) {
        guard action != state.sessionTimeoutAction else { return }
        if action == .logout {
            coordinator.navigate(to: .alert(.logoutOnTimeoutAlert {
                // TODO: BIT-1125 Persist the setting
                self.state.sessionTimeoutAction = action
            }))
        } else {
            // TODO: BIT-1125 Persist the setting
            state.sessionTimeoutAction = action
        }
    }

    /// Shows the account fingerprint phrase alert.
    ///
    private func showAccountFingerprintPhraseAlert() async {
        do {
            let userId = try await services.stateService.getActiveAccountId()
            let phrase = try await services.authRepository.getFingerprintPhrase(userId: userId)

            coordinator.navigate(to: .alert(
                .displayFingerprintPhraseAlert({
                    self.state.fingerprintPhraseUrl = ExternalLinksConstants.fingerprintPhrase
                }, phrase: phrase))
            )
        } catch {
            coordinator.navigate(to: .alert(.defaultAlert(title: Localizations.anErrorHasOccurred)))
        }
    }

    /// Shows an alert asking the user to confirm that they want to logout.
    ///
    private func showLogoutConfirmation() {
        let alert = Alert.logoutConfirmation {
            do {
                try await self.services.settingsRepository.logout()
            } catch {
                self.services.errorReporter.log(error: error)
            }
            self.coordinator.navigate(to: .logout)
        }
        coordinator.navigate(to: .alert(alert))
    }

    /// Shows the two step login alert. If `Yes` is selected, the user will be
    /// navigated to the web app.
    ///
    private func showTwoStepLoginAlert() {
        coordinator.navigate(to: .alert(.twoStepLoginAlert {
            self.state.twoStepLoginUrl = self.services.twoStepLoginService.twoStepLoginUrl()
        }))
    }

    /// Sets the user's biometric auth
    ///
    /// - Parameter enabled: Whether or not the the user wants biometric auth enabled.
    ///
    private func setBioMetricAuth(_ enabled: Bool) async {
        do {
            try await services.authRepository.allowBioMetricUnlock(enabled, userId: nil)
            state.biometricUnlockStatus = try await services.biometricsService.getBiometricUnlockStatus()
            // Set biometric integrity if needed.
            if case .available(_, true, false) = state.biometricUnlockStatus {
                try await services.biometricsService.configureBiometricIntegrity()
                state.biometricUnlockStatus = try await services.biometricsService.getBiometricUnlockStatus()
            }
        } catch {
            services.errorReporter.log(error: error)
        }
    }

    /// Shows an alert prompting the user to enter their PIN. If set successfully, the toggle will be turned on.
    ///
    /// - Parameter isOn: Whether or not the toggle value is true or false.
    ///
    private func toggleUnlockWithPIN(_ isOn: Bool) {
        if !state.isUnlockWithPINCodeOn {
            coordinator.navigate(
                to: .alert(
                    .enterPINCode(completion: { _ in
                        self.state.isUnlockWithPINCodeOn = isOn
                    })
                )
            )
        } else {
            state.isUnlockWithPINCodeOn = isOn
        }
    }
}
