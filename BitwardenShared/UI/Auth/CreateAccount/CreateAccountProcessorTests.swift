import Networking
import XCTest

@testable import BitwardenShared

// MARK: - CreateAccountProcessorTests

// swiftlint:disable:next type_body_length
class CreateAccountProcessorTests: BitwardenTestCase {
    // MARK: Properties

    var authRepository: MockAuthRepository!
    var captchaService: MockCaptchaService!
    var client: MockHTTPClient!
    var clientAuth: MockClientAuth!
    var coordinator: MockCoordinator<AuthRoute, AuthEvent>!
    var subject: CreateAccountProcessor!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        authRepository = MockAuthRepository()
        captchaService = MockCaptchaService()
        client = MockHTTPClient()
        clientAuth = MockClientAuth()
        coordinator = MockCoordinator<AuthRoute, AuthEvent>()
        subject = CreateAccountProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            services: ServiceContainer.withMocks(
                authRepository: authRepository,
                captchaService: captchaService,
                clientService: MockClientService(clientAuth: clientAuth),
                httpClient: client
            ),
            state: CreateAccountState()
        )
    }

    override func tearDown() {
        super.tearDown()
        authRepository = nil
        captchaService = nil
        clientAuth = nil
        client = nil
        coordinator = nil
        subject = nil
    }

    // MARK: Tests

    /// `captchaCompleted()` makes the create account request again, this time with a captcha token.
    /// Also tests that the user is then navigated to the login screen.
    func test_captchaCompleted() throws {
        CreateAccountRequestModel.encoder.outputFormatting = .sortedKeys
        subject.state.isTermsAndPrivacyToggleOn = true
        clientAuth.hashPasswordResult = .success("hashed password")
        client.result = .httpSuccess(testData: .createAccountRequest)
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.emailText = "email@example.com"
        subject.captchaCompleted(token: "token")

        let createAccountRequest = CreateAccountRequestModel(
            captchaResponse: "token",
            email: "email@example.com",
            kdfConfig: KdfConfig(),
            key: "encryptedUserKey",
            keys: KeysRequestModel(
                publicKey: "public",
                encryptedPrivateKey: "private"
            ),
            masterPasswordHash: "hashed password",
            masterPasswordHint: ""
        )

        waitFor(!coordinator.routes.isEmpty)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].body, try createAccountRequest.encode())
        XCTAssertEqual(clientAuth.hashPasswordPassword, "password1234")
        XCTAssertEqual(clientAuth.hashPasswordKdfParams, .pbkdf2(iterations: 600_000))
        XCTAssertEqual(coordinator.routes.last, .login(username: "email@example.com"))
    }

    /// `perform(_:)` with `.createAccount` will still make the `CreateAccountRequest` when the HIBP
    /// network request fails.
    func test_perform_checkForBreachesAndCreateAccount_failure() async throws {
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.emailText = "email@example.com"

        client.results = [.httpFailure(URLError(.timedOut) as Error), .httpSuccess(testData: .createAccountRequest)]

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[0].url, URL(string: "https://api.pwnedpasswords.com/range/e6b6a"))
        XCTAssertEqual(client.requests[1].url, URL(string: "https://example.com/identity/accounts/register"))
        XCTAssertEqual(coordinator.routes.last, .login(username: "email@example.com"))
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the user has
    /// entered a password that has been found in a data breach. After tapping `Yes` to create
    /// an account anyways, the `CreateAccountRequest` is made.
    func test_perform_checkForBreachesAndCreateAccount_yesTapped() async throws {
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.emailText = "email@example.com"

        client.results = [.httpSuccess(testData: .hibpLeakedPasswords), .httpSuccess(testData: .createAccountRequest)]

        await subject.perform(.createAccount)

        guard case let .alert(alert) = coordinator.routes.last else {
            return XCTFail("Expected an `.alert` route, but found \(String(describing: coordinator.routes.last))")
        }

        try await alert.tapAction(title: Localizations.yes)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[0].url, URL(string: "https://api.pwnedpasswords.com/range/e6b6a"))
        XCTAssertEqual(client.requests[1].url, URL(string: "https://example.com/identity/accounts/register"))
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the user has
    /// entered a password that has been found in a data breach.
    func test_perfrom_checkForBreachesAndCreateAccount() async {
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.emailText = "email@example.com"

        subject.state.isTermsAndPrivacyToggleOn = true

        client.result = .httpSuccess(testData: .hibpLeakedPasswords)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].url, URL(string: "https://api.pwnedpasswords.com/range/e6b6a"))
        XCTAssertEqual(coordinator.routes.last, .alert(Alert(
            title: Localizations.weakAndExposedMasterPassword,
            message: Localizations.weakPasswordIdentifiedAndFoundInADataBreachAlertDescription,
            alertActions: [
                AlertAction(title: Localizations.no, style: .cancel),
                AlertAction(title: Localizations.yes, style: .default) { _ in },
            ]
        )))
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the email has already been taken.
    func test_perform_createAccount_accountAlreadyExists() async {
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        let response = HTTPResponse.failure(
            statusCode: 400,
            body: APITestData.createAccountAccountAlreadyExists.data
        )

        guard let errorResponse = try? ErrorResponseModel(response: response) else { return }

        client.result = .httpFailure(
            ServerError.error(errorResponse: errorResponse)
        )

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(
            coordinator.routes.last,
            .alert(
                .defaultAlert(
                    title: Localizations.anErrorHasOccurred,
                    message: "Email 'j@a.com' is already taken."
                )
            )
        )
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the email exceeds the maximum length.
    func test_perform_createAccount_emailExceedsMaxLength() async {
        subject.state.emailText = """
        eyrztwlvxqdksnmcbjgahfpouyqiwubfdzoxhjsrlnvgeatkcpimy\
        fqaxhztsowbmdkjlrpnuqvycigfexrvlosqtpnheujawzsdmkbfoy\
        cxqpwkzthbnmudxlysgarcejfqvopzrkihwdelbuxyfqnjsgptamcozrvihsl\
        nbujrtdosmvhxwyfapzcklqoxbgdvtfieqyuhwajnrpslmcskgzofdqehxcbv\
        omjltzafwudqypnisgrkeohycbvxjflaumtwzrdqnpsoiezgyhqbmxdlvnzwa\
        htjoekrcispgvyfbuqklszepjwdrantihxfcoygmuslqbajzdfgrkmwbpnouq\
        tlsvixechyfjslrdvngiwzqpcotxubamhyekufjrzdwmxihqkfonslbcjgtpu\
        voyaezrctudwlskjpvmfqhnxbriyg@example.com
        """
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        let response = HTTPResponse.failure(
            statusCode: 400,
            body: APITestData.createAccountEmailExceedsMaxLength.data
        )

        guard let errorResponse = try? ErrorResponseModel(response: response) else { return }

        client.result = .httpFailure(
            ServerError.error(errorResponse: errorResponse)
        )

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(
            coordinator.routes.last,
            .alert(
                .defaultAlert(
                    title: Localizations.anErrorHasOccurred,
                    message: "The field Email must be a string with a maximum length of 256."
                )
            )
        )
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the email field is empty.
    func test_perform_createAccount_emptyEmail() async {
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false
        subject.state.emailText = ""

        client.result = .httpSuccess(testData: .createAccountSuccess)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 0)
        XCTAssertEqual(coordinator.routes.last, .alert(.validationFieldRequired(fieldName: "Email")))
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the password field is empty.
    func test_perform_createAccount_emptyPassword() async {
        subject.state.passwordText = ""
        subject.state.retypePasswordText = ""
        subject.state.emailText = "email@example.com"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        client.result = .httpSuccess(testData: .createAccountSuccess)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 0)
        XCTAssertEqual(coordinator.routes.last, .alert(.validationFieldRequired(fieldName: "Master password")))
    }

    /// `perform(_:)` with `.createAccount` and a captcha error occurs navigates to the `.captcha` route.
    func test_perform_createAccount_captchaError() async {
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        client.result = .httpFailure(CreateAccountRequestError.captchaRequired(hCaptchaSiteCode: "token"))

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(captchaService.callbackUrlSchemeGets, 1)
        XCTAssertEqual(captchaService.generateCaptchaSiteKey, "token")
        XCTAssertEqual(coordinator.routes.last, .captcha(url: .example, callbackUrlScheme: "callback"))
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the password hint is too long.
    func test_perform_createAccount_hintTooLong() async {
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "123456789012"
        subject.state.retypePasswordText = "123456789012"
        subject.state.passwordHintText = """
        ajajajajajajajajajajajajajajajajajajajajajajajajajajajajajajajajajajaj
        ajajajajajajajajajajajajajajajajajajajajajajajajajajajajajsjajajajajaj
        """
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        let response = HTTPResponse.failure(
            statusCode: 400,
            body: APITestData.createAccountHintTooLong.data
        )

        guard let errorResponse = try? ErrorResponseModel(response: response) else { return }

        client.result = .httpFailure(
            ServerError.error(errorResponse: errorResponse)
        )

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(
            coordinator.routes.last,
            .alert(
                .defaultAlert(
                    title: Localizations.anErrorHasOccurred,
                    message: "The field MasterPasswordHint must be a string with a maximum length of 50."
                )
            )
        )
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the email is in an invalid format.
    func test_perform_createAccount_invalidEmailFormat() async {
        subject.state.emailText = "∫@ø.com"
        subject.state.passwordText = "123456789012"
        subject.state.retypePasswordText = "123456789012"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        let response = HTTPResponse.failure(
            statusCode: 400,
            body: APITestData.createAccountInvalidEmailFormat.data
        )

        guard let errorResponse = try? ErrorResponseModel(response: response) else { return }

        client.result = .httpFailure(
            ServerError.error(errorResponse: errorResponse)
        )

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(
            coordinator.routes.last,
            .alert(
                .defaultAlert(
                    title: Localizations.anErrorHasOccurred,
                    message: "The Email field is not a supported e-mail address format."
                )
            )
        )
    }

    /// `perform(_:)` with `.createAccount` presents an alert when there is no internet connection.
    /// When the user taps `Try again`, the create account request is made again.
    func test_perform_createAccount_noInternetConnection() async throws {
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        let urlError = URLError(.notConnectedToInternet) as Error
        client.results = [.httpFailure(urlError), .httpSuccess(testData: .createAccountRequest)]

        await subject.perform(.createAccount)

        guard case let .alert(alert) = coordinator.routes.last else {
            return XCTFail("Expected an `.alert` route, but found \(String(describing: coordinator.routes.last))")
        }

        XCTAssertEqual(alert, Alert.networkResponseError(urlError) {
            await self.subject.perform(.createAccount)
        })

        try await alert.tapAction(title: Localizations.tryAgain)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[0].url, URL(string: "https://example.com/identity/accounts/register"))
        XCTAssertEqual(client.requests[1].url, URL(string: "https://example.com/identity/accounts/register"))
        XCTAssertEqual(coordinator.routes.last, .login(username: "email@example.com"))
    }

    /// `perform(_:)` with `.createAccount` presents an alert when password confirmation is incorrect.
    func test_perform_createAccount_passwordsDontMatch() async {
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "123456789012"
        subject.state.retypePasswordText = "123456789000"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        client.result = .httpSuccess(testData: .createAccountSuccess)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 0)
        XCTAssertEqual(coordinator.routes.last, .alert(.passwordsDontMatch))
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the password isn't long enough.
    func test_perform_createAccount_passwordsTooShort() async {
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "123"
        subject.state.retypePasswordText = "123"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        client.result = .httpSuccess(testData: .createAccountSuccess)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 0)
        XCTAssertEqual(coordinator.routes.last, .alert(.passwordIsTooShort))
    }

    /// `perform(_:)` with `.createAccount` presents an alert when the request times out.
    /// When the user taps `Try again`, the create account request is made again.
    func test_perform_createAccount_timeout() async throws {
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "password1234"
        subject.state.retypePasswordText = "password1234"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        let urlError = URLError(.timedOut) as Error
        client.results = [.httpFailure(urlError), .httpSuccess(testData: .createAccountRequest)]

        await subject.perform(.createAccount)

        guard case let .alert(alert) = coordinator.routes.last else {
            return XCTFail("Expected an `.alert` route, but found \(String(describing: coordinator.routes.last))")
        }

        XCTAssertEqual(alert.message, urlError.localizedDescription)

        try await alert.tapAction(title: Localizations.tryAgain)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[0].url, URL(string: "https://example.com/identity/accounts/register"))
        XCTAssertEqual(client.requests[1].url, URL(string: "https://example.com/identity/accounts/register"))
        XCTAssertEqual(coordinator.routes.last, .login(username: "email@example.com"))
    }

    /// `perform(_:)` with `.createAccount` and an invalid email navigates to an invalid email alert.
    func test_perform_createAccount_withInvalidEmail() async {
        subject.state.emailText = "exampleemail.com"
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.isCheckDataBreachesToggleOn = false

        client.result = .httpFailure(CreateAccountError.invalidEmail)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 0)
        XCTAssertEqual(coordinator.routes.last, .alert(.invalidEmail))
    }

    /// `perform(_:)` with `.createAccount` and a valid email creates the user's account.
    func test_perform_createAccount_withValidEmail() async {
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "123456789012"
        subject.state.retypePasswordText = "123456789012"

        client.result = .httpSuccess(testData: .createAccountSuccess)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests.first?.body, nil)
        XCTAssertEqual(client.requests[0].url, URL(string: "https://api.pwnedpasswords.com/range/8d993"))
        XCTAssertEqual(client.requests[1].url, URL(string: "https://example.com/identity/accounts/register"))
    }

    /// `perform(_:)` with `.createAccount` and a valid email surrounded by whitespace trims the whitespace and
    /// creates the user's account
    func test_perform_createAccount_withValidEmailAndSpace() async {
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.passwordText = "123456789012"
        subject.state.retypePasswordText = "123456789012"
        subject.state.emailText = " email@example.com "

        client.result = .httpSuccess(testData: .createAccountSuccess)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests.first?.body, nil)
        XCTAssertEqual(client.requests[0].url, URL(string: "https://api.pwnedpasswords.com/range/8d993"))
        XCTAssertEqual(client.requests[1].url, URL(string: "https://example.com/identity/accounts/register"))
    }

    /// `perform(_:)` with `.createAccount` and a valid email with uppercase characters converts the email to lowercase
    /// and creates the user's account.
    func test_perform_createAccount_withValidEmailUppercased() async {
        subject.state.isTermsAndPrivacyToggleOn = true
        subject.state.emailText = "EMAIL@EXAMPLE.COM"
        subject.state.passwordText = "123456789012"
        subject.state.retypePasswordText = "123456789012"

        client.result = .httpSuccess(testData: .createAccountSuccess)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests.first?.body, nil)
        XCTAssertEqual(client.requests[0].url, URL(string: "https://api.pwnedpasswords.com/range/8d993"))
        XCTAssertEqual(client.requests[1].url, URL(string: "https://example.com/identity/accounts/register"))
    }

    /// `perform(_:)` with `.createAccount` navigates to an error alert when the terms of service
    /// and privacy policy toggle is off.
    func test_perform_createAccount_withTermsAndServicesToggle_false() async {
        subject.state.isTermsAndPrivacyToggleOn = false
        subject.state.isCheckDataBreachesToggleOn = false
        subject.state.emailText = "email@example.com"
        subject.state.passwordText = "123456789012"
        subject.state.retypePasswordText = "123456789012"

        client.result = .httpSuccess(testData: .createAccountSuccess)

        await subject.perform(.createAccount)

        XCTAssertEqual(client.requests.count, 0)
        XCTAssertEqual(coordinator.routes.last, .alert(.acceptPoliciesAlert()))
    }

    /// `receive(_:)` with `.dismiss` dismisses the view.
    func test_receive_dismiss() {
        subject.receive(.dismiss)
        XCTAssertEqual(coordinator.routes.last, .dismiss)
    }

    /// `receive(_:)` with `.emailTextChanged(_:)` updates the state to reflect the change.
    func test_receive_emailTextChanged() {
        subject.state.emailText = ""
        XCTAssertTrue(subject.state.emailText.isEmpty)

        subject.receive(.emailTextChanged("updated email"))
        XCTAssertTrue(subject.state.emailText == "updated email")
    }

    /// `receive(_:)` with `.passwordHintTextChanged(_:)` updates the state to reflect the change.
    func test_receive_passwordHintTextChanged() {
        subject.state.passwordHintText = ""
        XCTAssertTrue(subject.state.passwordHintText.isEmpty)

        subject.receive(.passwordHintTextChanged("updated hint"))
        XCTAssertTrue(subject.state.passwordHintText == "updated hint")
    }

    /// `receive(_:)` with `.passwordTextChanged(_:)` updates the state to reflect the change.
    func test_receive_passwordTextChanged() {
        subject.state.passwordText = ""
        XCTAssertTrue(subject.state.passwordText.isEmpty)

        subject.receive(.passwordTextChanged("updated password"))
        XCTAssertTrue(subject.state.passwordText == "updated password")
    }

    /// `receive(_:)` with `.passwordTextChanged(_:)` updates the password strength score based on
    /// the entered password.
    func test_receive_passwordTextChanged_updatesPasswordStrength() {
        subject.state.emailText = "user@bitwarden.com"
        subject.receive(.passwordTextChanged(""))
        XCTAssertNil(subject.state.passwordStrengthScore)
        XCTAssertNil(authRepository.passwordStrengthPassword)

        authRepository.passwordStrengthResult = 0
        subject.receive(.passwordTextChanged("T"))
        waitFor(subject.state.passwordStrengthScore == 0)
        XCTAssertEqual(subject.state.passwordStrengthScore, 0)
        XCTAssertEqual(authRepository.passwordStrengthEmail, "user@bitwarden.com")
        XCTAssertEqual(authRepository.passwordStrengthPassword, "T")

        authRepository.passwordStrengthResult = 4
        subject.receive(.passwordTextChanged("TestPassword1234567890!@#"))
        waitFor(subject.state.passwordStrengthScore == 4)
        XCTAssertEqual(subject.state.passwordStrengthScore, 4)
        XCTAssertEqual(authRepository.passwordStrengthEmail, "user@bitwarden.com")
        XCTAssertEqual(authRepository.passwordStrengthPassword, "TestPassword1234567890!@#")
    }

    /// `receive(_:)` with `.retypePasswordTextChanged(_:)` updates the state to reflect the change.
    func test_receive_retypePasswordTextChanged() {
        subject.state.retypePasswordText = ""
        XCTAssertTrue(subject.state.retypePasswordText.isEmpty)

        subject.receive(.retypePasswordTextChanged("updated re-type"))
        XCTAssertTrue(subject.state.retypePasswordText == "updated re-type")
    }

    /// `receive(_:)` with `.toggleCheckDataBreaches(_:)` updates the state to reflect the change.
    func test_receive_toggleCheckDataBreaches() {
        subject.receive(.toggleCheckDataBreaches(false))
        XCTAssertFalse(subject.state.isCheckDataBreachesToggleOn)

        subject.receive(.toggleCheckDataBreaches(true))
        XCTAssertTrue(subject.state.isCheckDataBreachesToggleOn)

        subject.receive(.toggleCheckDataBreaches(true))
        XCTAssertTrue(subject.state.isCheckDataBreachesToggleOn)
    }

    /// `receive(_:)` with `.togglePasswordVisibility(_:)` updates the state to reflect the change.
    func test_receive_togglePasswordVisibility() {
        subject.state.arePasswordsVisible = false

        subject.receive(.togglePasswordVisibility(true))
        XCTAssertTrue(subject.state.arePasswordsVisible)

        subject.receive(.togglePasswordVisibility(true))
        XCTAssertTrue(subject.state.arePasswordsVisible)

        subject.receive(.togglePasswordVisibility(false))
        XCTAssertFalse(subject.state.arePasswordsVisible)
    }

    /// `receive(_:)` with `.toggleTermsAndPrivacy(_:)` updates the state to reflect the change.
    func test_receive_toggleTermsAndPrivacy() {
        subject.receive(.toggleTermsAndPrivacy(false))
        XCTAssertFalse(subject.state.isTermsAndPrivacyToggleOn)

        subject.receive(.toggleTermsAndPrivacy(true))
        XCTAssertTrue(subject.state.isTermsAndPrivacyToggleOn)

        subject.receive(.toggleTermsAndPrivacy(true))
        XCTAssertTrue(subject.state.isTermsAndPrivacyToggleOn)
    }
    // swiftlint:disable:next file_length
}
