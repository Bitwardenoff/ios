import BitwardenSdk

/// A helper class to handle when a cipher is selected for autofill.
///
@MainActor
class AutofillHelper {
    // MARK: Types

    typealias Services = HasErrorReporter
        & HasPasteboardService
        & HasVaultRepository

    // MARK: Properties

    /// A delegate used to communicate with the app extension.
    private weak var appExtensionDelegate: AppExtensionDelegate?

    /// The `Coordinator` that handles navigation.
    private let coordinator: AnyCoordinator<VaultRoute>

    /// The services used by this helper.
    private let services: Services

    // MARK: Initialization

    /// Initialize an `AutofillHelper`.
    ///
    /// - Parameters:
    ///   - appExtensionDelegate: A delegate used to communicate with the app extension.
    ///   - coordinator: The coordinator that handles navigation.
    ///   - services: The services used by this processor.
    ///
    init(
        appExtensionDelegate: AppExtensionDelegate?,
        coordinator: AnyCoordinator<VaultRoute>,
        services: Services
    ) {
        self.appExtensionDelegate = appExtensionDelegate
        self.coordinator = coordinator
        self.services = services
    }

    // MARK: Methods

    /// Handles autofill for a selected cipher.
    ///
    /// - Parameters:
    ///   - cipherView: The `CipherView` to use for autofill.
    ///   - showToast: A closure that when called will display a toast to the user.
    ///
    func handleCipherForAutofill(cipherView: CipherView, showToast: @escaping (String) -> Void) async {
        if cipherView.reprompt == .password {
            presentMasterPasswordRepromptAlert {
                self.handleCipherForAutofillAfterRepromptIfRequired(cipherView: cipherView, showToast: showToast)
            }
        } else {
            handleCipherForAutofillAfterRepromptIfRequired(cipherView: cipherView, showToast: showToast)
        }
    }

    /// Handles autofill for a selected cipher.
    ///
    /// - Parameters
    ///   - cipherListView: The `CipherListView` to use for autofill.
    ///   - showToast: A closure that when called will display a toast to the user.
    ///
    func handleCipherForAutofill(cipherListView: CipherListView, showToast: @escaping (String) -> Void) async {
        guard let cipherId = cipherListView.id else {
            coordinator.showAlert(.defaultAlert(title: Localizations.anErrorHasOccurred))
            return
        }

        guard let cipherView = try? await services.vaultRepository.fetchCipher(withId: cipherId) else {
            coordinator.showAlert(.defaultAlert(title: Localizations.anErrorHasOccurred))
            return
        }

        await handleCipherForAutofill(cipherView: cipherView, showToast: showToast)
    }

    // MARK: Private

    /// Handles autofill for a cipher after the master password reprompt has been confirmed, if it's
    /// required by the cipher.
    ///
    /// - Parameters
    ///   - cipherView: The `CipherView` to use for autofill.
    ///   - showToast: A closure that when called will display a toast to the user.
    ///
    private func handleCipherForAutofillAfterRepromptIfRequired(
        cipherView: CipherView,
        showToast: @escaping (String) -> Void
    ) {
        guard let username = cipherView.login?.username, !username.isEmpty,
              let password = cipherView.login?.password, !password.isEmpty else {
            handleMissingValueForAutofill(cipherView: cipherView, showToast: showToast)
            return
        }

        // TODO: BIT-1096 Copy TOTP

        appExtensionDelegate?.completeAutofillRequest(username: username, password: password)
    }

    /// Handles the case where the username or password is missing for the cipher which prevents it
    /// from being used for autofill.
    ///
    /// - Parameters
    ///   - cipherView: The `CipherView` to use for autofill.
    ///   - showToast: A closure that when called will display a toast to the user.
    ///
    private func handleMissingValueForAutofill(cipherView: CipherView, showToast: @escaping (String) -> Void) {
        guard let login = cipherView.login,
              !login.username.isEmptyOrNil ||
              !login.password.isEmptyOrNil ||
              !login.totp.isEmptyOrNil
        else {
            coordinator.showAlert(.defaultAlert(title: Localizations.noUsernamePasswordConfigured))
            return
        }

        let alert = Alert(title: cipherView.name, message: nil, preferredStyle: .actionSheet)

        if let username = login.username, !username.isEmpty {
            alert.add(AlertAction(title: Localizations.copyUsername, style: .default) { _ in
                self.services.pasteboardService.copy(username)
                showToast(Localizations.valueHasBeenCopied(Localizations.username))
            })
        }

        if let password = login.password, !password.isEmpty {
            alert.add(AlertAction(title: Localizations.copyPassword, style: .default) { _ in
                self.services.pasteboardService.copy(password)
                showToast(Localizations.valueHasBeenCopied(Localizations.password))
            })
        }

        if let totp = login.totp, !totp.isEmpty {
            alert.add(AlertAction(title: Localizations.copyTotp, style: .default) { _ in
                // TODO: BIT-1096 Generate and copy TOTP
                self.services.pasteboardService.copy(totp)
                showToast(Localizations.valueHasBeenCopied(Localizations.verificationCodeTotp))
            })
        }

        alert.add(AlertAction(title: Localizations.cancel, style: .cancel))

        coordinator.showAlert(alert)
    }

    /// Presents the master password reprompt alert and calls the completion handler when the user's
    /// master password has been confirmed.
    ///
    /// - Parameter completion: A completion handler that is called when the user's master password
    ///     has been confirmed.
    ///
    private func presentMasterPasswordRepromptAlert(completion: @escaping () -> Void) {
        let alert = Alert.masterPasswordPrompt { [weak self] password in
            guard let self else { return }

            do {
                let isValid = try await services.vaultRepository.validatePassword(password)
                guard isValid else {
                    coordinator.showAlert(.defaultAlert(title: Localizations.invalidMasterPassword))
                    return
                }
                completion()
            } catch {
                services.errorReporter.log(error: error)
            }
        }
        coordinator.showAlert(alert)
    }
}
