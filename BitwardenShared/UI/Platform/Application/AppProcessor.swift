import AuthenticationServices
import Combine
import Foundation
import UIKit

/// The `AppProcessor` processes actions received at the application level and contains the logic
/// to control the top-level flow through the app.
///
@MainActor
public class AppProcessor {
    // MARK: Properties

    /// The root module to use to create sub-coordinators.
    let appModule: AppModule

    /// The root coordinator of the app.
    var coordinator: AnyCoordinator<AppRoute, AppEvent>?

    /// The services used by the app.
    let services: ServiceContainer

    // MARK: Initialization

    /// Initializes an `AppProcessor`.
    ///
    /// - Parameters:
    ///   - appModule: The root module to use to create sub-coordinators.
    ///   - services: The services used by the app.
    ///
    public init(
        appModule: AppModule,
        services: ServiceContainer
    ) {
        self.appModule = appModule
        self.services = services

        self.services.notificationService.setDelegate(self)
        self.services.syncService.delegate = self

        UI.initialLanguageCode = services.appSettingsStore.appLocale ?? Locale.current.languageCode
        UI.applyDefaultAppearances()

        Task {
            for await _ in services.notificationCenterService.willEnterForegroundPublisher() {
                let accounts = try await self.services.stateService.getAccounts()
                let activeUserId = try await self.services.stateService.getActiveAccountId()
                for account in accounts {
                    let userId = account.profile.userId
                    let shouldTimeout = try await services.vaultTimeoutService.hasPassedSessionTimeout(userId: userId)
                    if shouldTimeout {
                        await self.services.vaultTimeoutService.lockVault(userId: userId)

                        if userId == activeUserId {
                            // Allow the AuthCoordinator to handle the timeout.
                            await coordinator?.handleEvent(.didTimeout(userId: activeUserId))
                        }
                    }
                }
            }
        }

        Task {
            for await _ in services.notificationCenterService.didEnterBackgroundPublisher() {
                let userId = try await self.services.stateService.getActiveAccountId()
                try await services.vaultTimeoutService.setLastActiveTime(userId: userId)
            }
        }
    }

    // MARK: Methods

    /// Handles receiving a deep link URL and routing to the appropriate place in the app.
    ///
    /// - Parameter url: The deep link URL to handle.
    ///
    public func openUrl(_ url: URL) async {
        guard let otpAuthModel = OTPAuthModel(otpAuthKey: url.absoluteString) else {
            coordinator?.showAlert(.defaultAlert(title: Localizations.anErrorHasOccurred))
            return
        }
        coordinator?.navigate(to: .tab(.vault(.vaultItemSelection(otpAuthModel))))
    }

    /// Starts the application flow by navigating the user to the first flow.
    ///
    /// - Parameters:
    ///   - appContext: The context that the app is running within.
    ///   - initialRoute: The initial route to navigate to. If `nil` this, will navigate to the
    ///     unlock or landing auth route based on if there's an active account. Defaults to `nil`.
    ///   - navigator: The object that will be used to navigate between routes.
    ///   - window: The window to use to set the app's theme.
    ///
    public func start(
        appContext: AppContext,
        initialRoute: AppRoute? = nil,
        navigator: RootNavigator,
        window: UIWindow?
    ) async {
        let coordinator = appModule.makeAppCoordinator(appContext: appContext, navigator: navigator)
        coordinator.start()
        self.coordinator = coordinator

        Task {
            for await appTheme in await services.stateService.appThemePublisher().values {
                navigator.appTheme = appTheme
                window?.overrideUserInterfaceStyle = appTheme.userInterfaceStyle
            }
        }

        await services.migrationService.performMigrations()
        await services.environmentService.loadURLsForActiveAccount()
        _ = await services.configService.getConfig()

        if let initialRoute {
            coordinator.navigate(to: initialRoute)
        } else {
            await coordinator.handleEvent(.didStart)
        }
    }

    // MARK: Autofill Methods

    /// Returns a `ASPasswordCredential` that matches the user-requested credential which can be
    /// used for autofill.
    ///
    /// - Parameters:
    ///   - id: The identifier of the user-requested credential to return.
    ///   - repromptPasswordValidated: `true` if master password reprompt was required for the
    ///     cipher and the user's master password was validated.
    /// - Returns: A `ASPasswordCredential` that matches the user-requested credential which can be
    ///     used for autofill.
    ///
    public func provideCredential(
        for id: String,
        repromptPasswordValidated: Bool = false
    ) async throws -> ASPasswordCredential {
        try await services.autofillCredentialService.provideCredential(
            for: id,
            repromptPasswordValidated: repromptPasswordValidated
        )
    }

    /// Reprompts the user for their master password if the cipher for the user-requested credential
    /// requires reprompt. Once reprompt has been completed (or when it's not required), the
    /// `completion` closure is called notifying the caller if the master password was validated
    /// successfully for reprompt.
    ///
    /// - Parameters:
    ///   - id: The identifier of the user-requested credential to return.
    ///   - completion: A closure that is called containing a bool that identifies if the user's
    ///     master password was validated successfully. This will be `false` if reprompt wasn't
    ///     required or if it is required and the master password was incorrect.
    ///
    public func repromptForCredentialIfNecessary(
        for id: String,
        completion: @escaping (Bool) async -> Void
    ) async throws {
        guard try await services.vaultRepository.repromptRequiredForCipher(id: id) else {
            await completion(false)
            return
        }

        let alert = Alert.masterPasswordPrompt { password in
            do {
                let isValid = try await self.services.authRepository.validatePassword(password)
                guard isValid else {
                    self.coordinator?.showAlert(.defaultAlert(title: Localizations.invalidMasterPassword)) {
                        Task {
                            await completion(false)
                        }
                    }
                    return
                }
                await completion(true)
            } catch {
                self.services.errorReporter.log(error: error)
                await completion(false)
            }
        }
        coordinator?.showAlert(alert)
    }

    // MARK: Notification Methods

    /// Called when the app has registered for push notifications.
    ///
    /// - Parameter tokenData: The device token for push notifications.
    ///
    public func didRegister(withToken tokenData: Data) {
        Task {
            await services.notificationService.didRegister(withToken: tokenData)
        }
    }

    /// Called when the app failed to register for push notifications.
    ///
    /// - Parameter error: The error received.
    ///
    public func failedToRegister(_ error: Error) {
        services.errorReporter.log(error: error)
    }

    /// Called when the app has received data from a push notification.
    ///
    /// - Parameters:
    ///   - message: The content of the push notification.
    ///   - notificationDismissed: `true` if a notification banner has been dismissed.
    ///   - notificationTapped: `true` if a notification banner has been tapped.
    ///
    public func messageReceived(
        _ message: [AnyHashable: Any],
        notificationDismissed: Bool? = nil,
        notificationTapped: Bool? = nil
    ) async {
        await services.notificationService.messageReceived(
            message,
            notificationDismissed: notificationDismissed,
            notificationTapped: notificationTapped
        )
    }
}

// MARK: - NotificationServiceDelegate

extension AppProcessor: NotificationServiceDelegate {
    /// Users are logged out, route to landing page.
    ///
    func routeToLanding() async {
        coordinator?.navigate(to: .auth(.landing))
    }

    /// Show the login request.
    ///
    /// - Parameter loginRequest: The login request.
    ///
    func showLoginRequest(_ loginRequest: LoginRequest) {
        coordinator?.navigate(to: .loginRequest(loginRequest))
    }

    /// Switch the active account in order to show the login request, prompting the user if necessary.
    ///
    /// - Parameters:
    ///   - account: The account associated with the login request.
    ///   - loginRequest: The login request to show.
    ///   - showAlert: Whether to show the alert or simply switch the account.
    ///
    func switchAccounts(to account: Account, for loginRequest: LoginRequest, showAlert: Bool) {
        DispatchQueue.main.async {
            if showAlert {
                self.coordinator?.showAlert(.confirmation(
                    title: Localizations.logInRequested,
                    message: Localizations.loginAttemptFromXDoYouWantToSwitchToThisAccount(account.profile.email)
                ) {
                    self.switchAccounts(to: account.profile.userId, for: loginRequest)
                })
            } else {
                self.switchAccounts(to: account.profile.userId, for: loginRequest)
            }
        }
    }

    /// Switch to the specified account and show the login request.
    ///
    /// - Parameters:
    ///   - userId: The userId of the account to switch to.
    ///   - loginRequest: The login request to show.
    ///
    private func switchAccounts(to userId: String, for loginRequest: LoginRequest) {
        (coordinator as? VaultCoordinatorDelegate)?.didTapAccount(userId: userId)
        coordinator?.navigate(to: .loginRequest(loginRequest))
    }
}

// MARK: - SyncServiceDelegate

extension AppProcessor: SyncServiceDelegate {
    func securityStampChanged(userId: String) async {
        // Log the user out if their security stamp changes.
        coordinator?.hideLoadingOverlay()
        try? await services.authRepository.logout(userId: userId)
        await coordinator?.handleEvent(.didLogout(userId: userId, userInitiated: false))
    }

    func setMasterPassword(orgIdentifier: String) async {
        DispatchQueue.main.async { [self] in
            coordinator?.navigate(to: .auth(.setMasterPassword(organizationIdentifier: orgIdentifier)))
        }
    }
}
