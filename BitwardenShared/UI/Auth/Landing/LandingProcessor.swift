import Combine
import SwiftUI

// MARK: - LandingProcessor

/// The processor used to manage state and handle actions for the landing screen.
///
class LandingProcessor: StateProcessor<LandingState, LandingAction, LandingEffect> {
    // MARK: Types

    typealias Services = HasAppSettingsStore
        & HasAuthRepository
        & HasEnvironmentService
        & HasErrorReporter
        & HasStateService

    // MARK: Private Properties

    /// The coordinator that handles navigation.
    private let coordinator: AnyCoordinator<AuthRoute>

    /// The services required by this processor.
    private let services: Services

    // MARK: Initialization

    /// Creates a new `LandingProcessor`.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator that handles navigation.
    ///   - services: The services required by this processor.
    ///   - state: The initial state of the processor.
    ///
    init(
        coordinator: AnyCoordinator<AuthRoute>,
        services: Services,
        state: LandingState
    ) {
        self.coordinator = coordinator
        self.services = services

        let rememberedEmail = services.appSettingsStore.rememberedEmail
        var state = state
        state.email = rememberedEmail ?? ""
        state.isRememberMeOn = rememberedEmail != nil

        super.init(state: state)
    }

    // MARK: Methods

    /// Configures a profile switcher state with the current account and alternates.
    ///
    private func refreshProfileState() async {
        var accounts = [ProfileSwitcherItem]()
        var activeAccount: ProfileSwitcherItem?
        do {
            accounts = try await services.authRepository.getAccounts()
            guard !accounts.isEmpty else { return }
            activeAccount = try? await services.authRepository.getActiveAccount()
            state.profileSwitcherState = ProfileSwitcherState(
                accounts: accounts,
                activeAccountId: activeAccount?.userId,
                isVisible: state.profileSwitcherState.isVisible,
                shouldAlwaysHideAddAccount: true
            )
        } catch {
            state.profileSwitcherState = .empty(shouldAlwaysHideAddAccount: true)
        }
    }

    override func perform(_ effect: LandingEffect) async {
        switch effect {
        case .appeared:
            await loadRegion()
            await refreshProfileState()
        case let .profileSwitcher(profileEffect):
            switch profileEffect {
            case let .rowAppeared(rowType):
                guard state.profileSwitcherState.shouldSetAccessibilityFocus(for: rowType) == true else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.state.profileSwitcherState.hasSetAccessibilityFocus = true
                }
            }
        }
    }

    override func receive(_ action: LandingAction) {
        switch action {
        case .continuePressed:
            updateRememberedEmail()
            validateEmailAndContinue()
        case .createAccountPressed:
            coordinator.navigate(to: .createAccount)
        case let .emailChanged(newValue):
            state.email = newValue
        case let .profileSwitcherAction(profileAction):
            switch profileAction {
            case let .accountPressed(account):
                didTapProfileSwitcherItem(account)
            case .addAccountPressed:
                state.profileSwitcherState.isVisible = false
            case .backgroundPressed:
                state.profileSwitcherState.isVisible = false
            case let .requestedProfileSwitcher(visible: isVisible):
                state.profileSwitcherState.isVisible = isVisible
            case let .scrollOffsetChanged(newOffset):
                state.profileSwitcherState.scrollOffset = newOffset
            }
        case .regionPressed:
            presentRegionSelectionAlert()
        case let .rememberMeChanged(newValue):
            state.isRememberMeOn = newValue
            if !newValue {
                updateRememberedEmail()
            }
        }
    }

    // MARK: Private Methods

    /// Handles a tap of an account in the profile switcher
    /// - Parameter selectedAccount: The `ProfileSwitcherItem` selected by the user.
    ///
    private func didTapProfileSwitcherItem(_ selectedAccount: ProfileSwitcherItem) {
        defer { state.profileSwitcherState.isVisible = false }
        coordinator.navigate(
            to: .switchAccount(userId: selectedAccount.userId)
        )
    }

    /// Sets the region to the last used region.
    ///
    private func loadRegion() async {
        guard let urls = await services.stateService.getPreAuthEnvironmentUrls() else {
            await setRegion(.unitedStates, urls: .defaultUS)
            return
        }

        if urls.base == EnvironmentUrlData.defaultUS.base {
            await setRegion(.unitedStates, urls: urls)
        } else if urls.base == EnvironmentUrlData.defaultEU.base {
            await setRegion(.europe, urls: urls)
        } else {
            await setRegion(.selfHosted, urls: urls)
        }
    }

    /// Validate the currently entered email address and navigate to the login screen.
    ///
    private func validateEmailAndContinue() {
        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.isValidEmail else {
            coordinator.navigate(to: .alert(.invalidEmail))
            return
        }

        // Region placeholder until region selection support is added: BIT-268
        coordinator.navigate(to: .login(
            username: email,
            region: state.region,
            isLoginWithDeviceVisible: false
        ))
    }

    /// Builds an alert for region selection and navigates to the alert.
    ///
    private func presentRegionSelectionAlert() {
        let actions = RegionType.allCases.map { region in
            AlertAction(title: region.baseUrlDescription, style: .default) { [weak self] _ in
                if let urls = region.defaultURLs {
                    await self?.setRegion(region, urls: urls)
                } else {
                    self?.coordinator.navigate(to: .selfHosted, context: self)
                }
            }
        }
        let cancelAction = AlertAction(title: Localizations.cancel, style: .cancel)
        let alert = Alert(
            title: Localizations.loggingInOn,
            message: nil,
            preferredStyle: .actionSheet,
            alertActions: actions + [cancelAction]
        )
        coordinator.navigate(to: .alert(alert))
    }

    /// Sets the region and the URLs to use.
    ///
    /// - Parameters:
    ///   - region: The region to use.
    ///   - urls: The URLs that the app should use for the region.
    ///
    private func setRegion(_ region: RegionType, urls: EnvironmentUrlData) async {
        guard !urls.isEmpty else { return }
        await services.environmentService.setPreAuthURLs(urls: urls)
        state.region = region
    }

    /// Updates the value of `rememberedEmail` in the app settings store with the `email` value in `state`.
    ///
    private func updateRememberedEmail() {
        if state.isRememberMeOn {
            services.appSettingsStore.rememberedEmail = state.email
        } else {
            services.appSettingsStore.rememberedEmail = nil
        }
    }
}

// MARK: - SelfHostedProcessorDelegate

extension LandingProcessor: SelfHostedProcessorDelegate {
    func didSaveEnvironment(urls: EnvironmentUrlData) async {
        await setRegion(.selfHosted, urls: urls)
    }
}
