// MARK: - CaptchaFlowDelegate

/// An object that is signaled when specific circumstances in the captcha flow have been encountered.
///
protocol CaptchaFlowDelegate: AnyObject {
    /// Called when the captcha flow has been completed successfully.
    ///
    /// - Parameter token: The token that was returned by hCaptcha.
    ///
    func captchaCompleted(token: String)

    /// Called when the captcha flow encounters an error.
    ///
    /// - Parameter error: The error that was encountered.
    ///
    func captchaErrored(error: Error)
}

// MARK: - LoginProcessor

/// The processor used to manage state and handle actions for the login screen.
///
class LoginProcessor: StateProcessor<LoginState, LoginAction, LoginEffect> {
    // MARK: Types

    typealias Services = HasAccountAPIService
        & HasCaptchaService

    // MARK: Private Properties

    /// The `Coordinator` that handles navigation.
    private var coordinator: AnyCoordinator<AuthRoute>

    /// The services used by this processor.
    private var services: Services

    // MARK: Initialization

    /// Creates a new `LoginProcessor`.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator that handles navigation.
    ///   - state: The initial state of the processor.
    ///
    init(
        coordinator: AnyCoordinator<AuthRoute>,
        services: Services,
        state: LoginState
    ) {
        self.coordinator = coordinator
        self.services = services
        super.init(state: state)
    }

    // MARK: Methods

    override func perform(_ effect: LoginEffect) async {
        switch effect {
        case .loginWithMasterPasswordPressed:
            await loginWithMasterPassword()
        }
    }

    override func receive(_ action: LoginAction) {
        switch action {
        case .enterpriseSingleSignOnPressed:
            coordinator.navigate(to: .enterpriseSingleSignOn)
        case .getMasterPasswordHintPressed:
            coordinator.navigate(to: .masterPasswordHint)
        case .loginWithDevicePressed:
            coordinator.navigate(to: .loginWithDevice)
        case let .masterPasswordChanged(newValue):
            state.masterPassword = newValue
        case .morePressed:
            coordinator.navigate(to: .loginOptions)
        case .notYouPressed:
            coordinator.navigate(to: .landing)
        case .revealMasterPasswordFieldPressed:
            state.isMasterPasswordRevealed.toggle()
        }
    }

    // MARK: Private Methods

    /// Generates the items needed and authenticates with the captcha flow.
    ///
    /// - Parameter siteKey: The site key that was returned with a captcha error. The token used to authenticate
    ///   with hCaptcha.
    ///
    private func launchCaptchaFlow(with siteKey: String) async {
        do {
            let callbackUrlScheme = services.captchaService.callbackUrlScheme
            let url = try services.captchaService.generateCaptchaUrl(with: siteKey)
            coordinator.navigate(
                to: .captcha(
                    url: url,
                    callbackUrlScheme: callbackUrlScheme
                ),
                context: self
            )
        } catch {
            // Error handling will be added in BIT-549
            print(error)
        }
    }

    /// Attempts to log the user in with the email address and password values found in `state`.
    ///
    private func loginWithMasterPassword() async {
        coordinator.showLoadingOverlay(title: Localizations.loggingIn)
        defer { coordinator.hideLoadingOverlay() }

        do {
            _ = try await services.accountAPIService.preLogin(email: state.username)
            coordinator.navigate(to: .complete)
            // Encrypt the password with the kdf algorithm and send it to the server for verification: BIT-420
        } catch {
            // Error handling will be added in BIT-387

            // Replace the siteKey with the actual siteKey if a captcha error is detected.
            let siteKey = ""
            await launchCaptchaFlow(with: siteKey)
        }
    }
}

// MARK: CaptchaFlowDelegate

extension LoginProcessor: CaptchaFlowDelegate {
    func captchaCompleted(token: String) {
        // Actually do something with the captcha token here, send the identity token request: BIT-420
        print(token)
    }

    func captchaErrored(error: Error) {
        // Error handling will be added in BIT-549
        print(error)
    }
}
