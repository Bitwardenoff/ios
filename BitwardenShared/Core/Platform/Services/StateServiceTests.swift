import BitwardenSdk
import XCTest

@testable import BitwardenShared

class StateServiceTests: BitwardenTestCase { // swiftlint:disable:this type_body_length
    // MARK: Properties

    var appSettingsStore: MockAppSettingsStore!
    var dataStore: DataStore!
    var subject: DefaultStateService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        appSettingsStore = MockAppSettingsStore()
        dataStore = DataStore(errorReporter: MockErrorReporter(), storeType: .memory)

        subject = DefaultStateService(appSettingsStore: appSettingsStore, dataStore: dataStore)
    }

    override func tearDown() {
        super.tearDown()

        appSettingsStore = nil
        dataStore = nil
        subject = nil
    }

    // MARK: Tests

    /// `addAccount(_:)` adds an initial account and makes it the active account.
    func test_addAccount_initialAccount() async throws {
        let account = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        await subject.addAccount(account)

        let state = try XCTUnwrap(appSettingsStore.state)
        XCTAssertEqual(state.accounts, ["1": account])
        XCTAssertEqual(state.activeUserId, "1")
    }

    /// `addAccount(_:)` adds new account to the account list with existing accounts and makes it
    /// the active account.
    func test_addAccount_multipleAccounts() async throws {
        let existingAccount = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        await subject.addAccount(existingAccount)

        let newAccount = Account.fixture(profile: Account.AccountProfile.fixture(userId: "2"))
        await subject.addAccount(newAccount)

        let state = try XCTUnwrap(appSettingsStore.state)
        XCTAssertEqual(state.accounts, ["1": existingAccount, "2": newAccount])
        XCTAssertEqual(state.activeUserId, "2")
    }

    /// `appLocale` gets and sets the value as expected.
    func test_appLocale() {
        // Getting the value should get the value from the app settings store.
        appSettingsStore.appLocale = "de"
        XCTAssertEqual(subject.appLanguage, .custom(languageCode: "de"))

        // Setting the value should update the value in the app settings store.
        subject.appLanguage = .custom(languageCode: "th")
        XCTAssertEqual(appSettingsStore.appLocale, "th")
    }

    /// `appTheme` gets and sets the value as expected.
    func test_appTheme() async {
        // Getting the value should get the value from the app settings store.
        appSettingsStore.appTheme = "light"
        let theme = await subject.getAppTheme()
        XCTAssertEqual(theme, .light)

        // Setting the value should update the value in the app settings store.
        await subject.setAppTheme(.dark)
        XCTAssertEqual(appSettingsStore.appTheme, "dark")
    }

    /// `appThemePublisher()` returns a publisher for the app's theme.
    func test_appThemePublisher() async {
        var publishedValues = [AppTheme]()
        let publisher = await subject.appThemePublisher()
            .sink(receiveValue: { date in
                publishedValues.append(date)
            })
        defer { publisher.cancel() }

        await subject.setAppTheme(.dark)

        XCTAssertEqual(publishedValues, [.default, .dark])
    }

    /// `clearPins()` clears the user's pins.
    func test_clearPins() async throws {
        let account = Account.fixture()
        await subject.addAccount(account)

        try await subject.clearPins()
        let pinProtectedUserKey = try await subject.pinProtectedUserKey()
        let pinKeyEncryptedUserKey = try await subject.pinKeyEncryptedUserKey()

        XCTAssertNil(pinProtectedUserKey)
        XCTAssertNil(pinKeyEncryptedUserKey)
    }

    /// `deleteAccount()` deletes the active user's account, removing it from the state.
    func test_deleteAccount() async throws {
        let newAccount = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        await subject.addAccount(newAccount)

        try await subject.deleteAccount()

        // User is removed from the state.
        let state = try XCTUnwrap(appSettingsStore.state)
        XCTAssertTrue(state.accounts.isEmpty)
        XCTAssertNil(state.activeUserId)
    }

    /// `getAccountEncryptionKeys(_:)` returns the encryption keys for the user account.
    func test_getAccountEncryptionKeys() async throws {
        appSettingsStore.encryptedPrivateKeys["1"] = "1:PRIVATE_KEY"
        appSettingsStore.encryptedPrivateKeys["2"] = "2:PRIVATE_KEY"
        appSettingsStore.encryptedUserKeys["1"] = "1:USER_KEY"
        appSettingsStore.encryptedUserKeys["2"] = "2:USER_KEY"

        appSettingsStore.state?.activeUserId = nil
        await assertAsyncThrows(error: StateServiceError.noActiveAccount) {
            _ = try await subject.getAccountEncryptionKeys()
        }

        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))
        let accountKeys = try await subject.getAccountEncryptionKeys()
        XCTAssertEqual(
            accountKeys,
            AccountEncryptionKeys(
                encryptedPrivateKey: "1:PRIVATE_KEY",
                encryptedUserKey: "1:USER_KEY"
            )
        )

        await subject.addAccount(.fixture(profile: .fixture(userId: "2")))
        let otherAccountKeys = try await subject.getAccountEncryptionKeys()
        XCTAssertEqual(
            otherAccountKeys,
            AccountEncryptionKeys(
                encryptedPrivateKey: "2:PRIVATE_KEY",
                encryptedUserKey: "2:USER_KEY"
            )
        )

        let accountKeysForUserId = try await subject.getAccountEncryptionKeys(userId: "1")
        XCTAssertEqual(
            accountKeysForUserId,
            AccountEncryptionKeys(
                encryptedPrivateKey: "1:PRIVATE_KEY",
                encryptedUserKey: "1:USER_KEY"
            )
        )
    }

    /// `getAccountEncryptionKeys(_:)` throws an error if applicable.
    func test_getAccountEncryptionKeys_error() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        await assertAsyncThrows(error: StateServiceError.noActiveAccount) {
            _ = try await subject.getAccountEncryptionKeys()
        }
    }

    /// `getActiveAccount()` returns the active account.
    func test_getActiveAccount() async throws {
        let account = Account.fixture(profile: .fixture(userId: "2"))
        appSettingsStore.state = State.fixture(
            accounts: [
                "1": Account.fixture(),
                "2": account,
            ],
            activeUserId: "2"
        )

        let activeAccount = try await subject.getActiveAccount()
        XCTAssertEqual(activeAccount, account)
    }

    /// `getActiveAccount()` throws an error if there aren't isn't an active account.
    func test_getActiveAccount_noAccount() async throws {
        await assertAsyncThrows(error: StateServiceError.noActiveAccount) {
            _ = try await subject.getActiveAccount()
        }
    }

    /// `getActiveAccount()` returns the active account when there's a single account.
    func test_getActiveAccount_singleAccount() async throws {
        let account = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        await subject.addAccount(account)

        let activeAccount = try await subject.getActiveAccount()
        XCTAssertEqual(activeAccount, account)
    }

    /// `getAccounts()` returns the accounts when there's a single account.
    func test_getAccounts_singleAccount() async throws {
        let account = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        appSettingsStore.state = State(accounts: [account.profile.userId: account], activeUserId: nil)

        let accounts = try await subject.getAccounts()
        XCTAssertEqual(accounts, [account])
    }

    /// `getAccounts()` throws an error when there are no accounts.
    func test_getAccounts_noAccounts() async throws {
        appSettingsStore.state = nil

        await assertAsyncThrows(error: StateServiceError.noAccounts) {
            _ = try await subject.getAccounts()
        }
    }

    /// `getAccountIdOrActiveId(userId:)` throws an error when there is no active account.
    func test_getAccountIdOrActiveId_nil_noActiveAccount() async throws {
        appSettingsStore.state = State(accounts: [:], activeUserId: nil)

        await assertAsyncThrows(error: StateServiceError.noActiveAccount) {
            _ = try await subject.getAccountIdOrActiveId(userId: nil)
        }
    }

    /// `getAccountIdOrActiveId(userId:)` throws an error when there are no accounts.
    func test_getAccountIdOrActiveId_nil_noAccounts() async throws {
        appSettingsStore.state = nil

        await assertAsyncThrows(error: StateServiceError.noAccounts) {
            _ = try await subject.getAccountIdOrActiveId(userId: nil)
        }
    }

    /// `getAccountIdOrActiveId(userId:)` throws an error when there is no matching account.
    func test_getAccountIdOrActiveId_userId_noMatchingAccount() async throws {
        let account = Account.fixtureAccountLogin()
        appSettingsStore.state = State(accounts: [account.profile.userId: account], activeUserId: nil)

        await assertAsyncThrows(error: StateServiceError.noAccounts) {
            _ = try await subject.getAccountIdOrActiveId(userId: "123")
        }
    }

    /// `getAccountIdOrActiveId(userId:)` throws an error when there are no accounts.
    func test_getAccountIdOrActiveId_userId_noAccounts() async throws {
        appSettingsStore.state = nil

        await assertAsyncThrows(error: StateServiceError.noAccounts) {
            _ = try await subject.getAccountIdOrActiveId(userId: "123")
        }
    }

    /// `getAccountIdOrActiveId(userId:)` returns the id for a match
    func test_getAccountIdOrActiveId_userId_matchingAccount() async throws {
        let account = Account.fixtureAccountLogin()
        appSettingsStore.state = State(accounts: [account.profile.userId: account], activeUserId: nil)

        let accountId = try await subject.getAccountIdOrActiveId(userId: account.profile.userId)
        XCTAssertEqual(accountId, account.profile.userId)
    }

    /// `getAddSitePromptShown()` returns whether the autofill info prompt has been shown
    func test_getAddSitePromptShown() async {
        var hasShownPrompt = await subject.getAddSitePromptShown()
        XCTAssertFalse(hasShownPrompt)

        appSettingsStore.addSitePromptShown = true
        hasShownPrompt = await subject.getAddSitePromptShown()
        XCTAssertTrue(hasShownPrompt)
    }

    /// `allowSyncOnRefreshes()` returns the allow sync on refresh value for the active account.
    func test_getAllowSyncOnRefresh() async throws {
        await subject.addAccount(.fixture())
        appSettingsStore.allowSyncOnRefreshes["1"] = true
        let value = try await subject.getAllowSyncOnRefresh()
        XCTAssertTrue(value)
    }

    /// `allowSyncOnRefreshes()` defaults to `false` if the active account doesn't have a value set.
    func test_getAllowSyncOnRefresh_notSet() async throws {
        await subject.addAccount(.fixture())
        let value = try await subject.getAllowSyncOnRefresh()
        XCTAssertFalse(value)
    }

    /// `getClearClipboardValue()` returns the clear clipboard value for the active account.
    func test_getClearClipboardValue() async throws {
        await subject.addAccount(.fixture())
        appSettingsStore.clearClipboardValues["1"] = .twoMinutes
        let value = try await subject.getClearClipboardValue()
        XCTAssertEqual(value, .twoMinutes)
    }

    /// `getConfig()` returns the config values
    func test_getConfig() async {
        let model = ConfigResponseModel(
            version: "1.2.3",
            gitHash: "1234",
            server: nil,
            environment: nil,
            featureStates: [:]
        )
        appSettingsStore.config = model
        let value = await subject.getConfig()
        XCTAssertEqual(value, model)
    }

    /// `getBiometricAuthenticationEnabled(:)` returns biometric unlock preference of the active user.
    func test_getBiometricAuthenticationEnabled_default() async throws {
        await subject.addAccount(.fixture())
        appSettingsStore.biometricAuthenticationEnabled = [
            "1": true,
        ]
        let value = try await subject.getBiometricAuthenticationEnabled()
        XCTAssertTrue(value)
    }

    /// `getBiometricAuthenticationEnabled(:)` throws errors if no user exists.
    func test_getBiometricAuthenticationEnabled_error() async throws {
        await assertAsyncThrows(error: StateServiceError.noActiveAccount) {
            _ = try await subject.getBiometricAuthenticationEnabled()
        }
    }

    /// `getBiometricIntegrityState(:)` returns biometric integrity state of the active user.
    func test_getBiometricIntegrityState_active() async throws {
        await subject.addAccount(.fixture())
        appSettingsStore.biometricIntegrityStates = [
            "1": "Expected State",
        ]
        let value = try await subject.getBiometricIntegrityState()
        XCTAssertEqual(value, "Expected State")
    }

    /// `getBiometricIntegrityState(:)` returns the expected value.
    func test_getBiometricIntegrityState() async throws {
        await subject.addAccount(.fixture())
        appSettingsStore.biometricIntegrityStates = [
            "2": "Expected State",
        ]
        let value = try await subject.getBiometricIntegrityState()
        XCTAssertNil(value, "Expected State")
    }

    /// `getBiometricIntegrityState(:)` returns biometric integrity state of the active user.
    func test_getBiometricIntegrityState_error() async throws {
        appSettingsStore.biometricIntegrityStates = [
            "2": "Expected State",
        ]
        await assertAsyncThrows(error: StateServiceError.noActiveAccount) {
            _ = try await subject.getBiometricIntegrityState()
        }
    }

    /// `getConnectToWatch()` returns the connect to watch value for the active account.
    func test_getConnectToWatch() async throws {
        await subject.addAccount(.fixture())
        appSettingsStore.connectToWatchByUserId["1"] = true
        let value = try await subject.getConnectToWatch()
        XCTAssertTrue(value)
    }

    /// `getClearClipboardValue()` returns `.never` if the active account doesn't have a value set.
    func test_getClearClipboardValue_notSet() async throws {
        await subject.addAccount(.fixture())
        let value = try await subject.getClearClipboardValue()
        XCTAssertEqual(value, .never)
    }

    /// `getDefaultUriMatchType()` returns the default URI match type value for the active account.
    func test_getDefaultUriMatchType() async throws {
        await subject.addAccount(.fixture())

        let initialValue = try await subject.getDefaultUriMatchType()
        XCTAssertEqual(initialValue, .domain)

        appSettingsStore.defaultUriMatchTypeByUserId["1"] = .exact
        let value = try await subject.getDefaultUriMatchType()
        XCTAssertEqual(value, .exact)
    }

    /// `getDisableAutoTotpCopy()` returns the disable auto-copy TOTP value for the active account.
    func test_getDisableAutoTotpCopy() async throws {
        await subject.addAccount(.fixture())
        appSettingsStore.disableAutoTotpCopyByUserId["1"] = true

        let value = try await subject.getDisableAutoTotpCopy()
        XCTAssertTrue(value)
    }

    /// `getEnvironmentUrls()` returns the environment URLs for the active account.
    func test_getEnvironmentUrls() async throws {
        let urls = EnvironmentUrlData(base: .example)
        let account = Account.fixture(settings: .fixture(environmentUrls: urls))
        appSettingsStore.state = State(
            accounts: [account.profile.userId: account],
            activeUserId: account.profile.userId
        )
        let accountUrls = try await subject.getEnvironmentUrls()
        XCTAssertEqual(accountUrls, urls)
    }

    /// `getEnvironmentUrls()` returns `nil` if the active account doesn't have URLs set.
    func test_getEnvironmentUrls_notSet() async throws {
        let account = Account.fixture(settings: .fixture(environmentUrls: nil))
        appSettingsStore.state = State(
            accounts: [account.profile.userId: account],
            activeUserId: account.profile.userId
        )
        let urls = try await subject.getEnvironmentUrls()
        XCTAssertNil(urls)
    }

    /// `getEnvironmentUrls()` returns `nil` if the user doesn't exist.
    func test_getEnvironmentUrls_noUser() async throws {
        let urls = try await subject.getEnvironmentUrls(userId: "-1")
        XCTAssertNil(urls)
    }

    /// `getLastActiveTime(userId:)` gets the user's last active time.
    func test_getLastActiveTime() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setLastActiveTime(Date())
        let lastActiveTime = try await subject.getLastActiveTime()
        XCTAssertEqual(
            lastActiveTime!.timeIntervalSince1970,
            Date().timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    /// `getLastSyncTime(userId:)` gets the user's last sync time.
    func test_getLastSyncTime() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        let noTime = try await subject.getLastSyncTime(userId: "1")
        XCTAssertNil(noTime)

        let date = Date(timeIntervalSince1970: 1_704_067_200)
        appSettingsStore.lastSyncTimeByUserId["1"] = date
        let lastSyncTime = try await subject.getLastSyncTime(userId: "1")
        XCTAssertEqual(lastSyncTime, date)
    }

    /// `getLoginRequest()` gets any pending login requests.
    func test_getLoginRequest() async {
        let loginRequest = LoginRequestNotification(id: "1", userId: "10")
        appSettingsStore.loginRequest = loginRequest
        let value = await subject.getLoginRequest()
        XCTAssertEqual(value, loginRequest)
    }

    /// `getMasterPasswordHash()` returns the user's master password hash.
    func test_getMasterPasswordHash() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        let noPasswordHash = try await subject.getMasterPasswordHash()
        XCTAssertNil(noPasswordHash)

        appSettingsStore.masterPasswordHashes["1"] = "abcd"
        let passwordHash = try await subject.getMasterPasswordHash()
        XCTAssertEqual(passwordHash, "abcd")
    }

    /// `getMasterPasswordHash()` throws an error if there isn't an active account.
    func test_getMasterPasswordHash_noAccount() async {
        await assertAsyncThrows(error: StateServiceError.noActiveAccount) {
            _ = try await subject.getMasterPasswordHash()
        }
    }

    /// `getNotificationsLastRegistrationDate()` returns the user's last notifications registration date.
    func test_getNotificationsLastRegistrationDate() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        let noDate = try await subject.getNotificationsLastRegistrationDate()
        XCTAssertNil(noDate)

        appSettingsStore.notificationsLastRegistrationDates["1"] = Date(year: 2024, month: 1, day: 1)
        let date = try await subject.getNotificationsLastRegistrationDate()
        XCTAssertEqual(date, Date(year: 2024, month: 1, day: 1))
    }

    /// `getPasswordGenerationOptions()` gets the saved password generation options for the account.
    func test_getPasswordGenerationOptions() async throws {
        let options1 = PasswordGenerationOptions(length: 30)
        let options2 = PasswordGenerationOptions(length: 50)

        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        appSettingsStore.passwordGenerationOptions = [
            "1": options1,
            "2": options2,
        ]

        let fetchedOptions1 = try await subject.getPasswordGenerationOptions(userId: "1")
        XCTAssertEqual(fetchedOptions1, options1)

        let fetchedOptions2 = try await subject.getPasswordGenerationOptions(userId: "2")
        XCTAssertEqual(fetchedOptions2, options2)

        let fetchedOptionsActiveAccount = try await subject.getPasswordGenerationOptions()
        XCTAssertEqual(fetchedOptionsActiveAccount, options1)

        let fetchedOptionsNoAccount = try await subject.getPasswordGenerationOptions(userId: "-1")
        XCTAssertNil(fetchedOptionsNoAccount)
    }

    /// `getPreAuthEnvironmentUrls` returns the saved pre-auth URLs.
    func test_getPreAuthEnvironmentUrls() async {
        let urls = EnvironmentUrlData(base: .example)
        appSettingsStore.preAuthEnvironmentUrls = urls
        let preAuthUrls = await subject.getPreAuthEnvironmentUrls()
        XCTAssertEqual(preAuthUrls, urls)
    }

    /// `getPreAuthEnvironmentUrls` returns `nil` if the URLs haven't been set.
    func test_getPreAuthEnvironmentUrls_notSet() async {
        let urls = await subject.getPreAuthEnvironmentUrls()
        XCTAssertNil(urls)
    }

    /// `getShowWebIcons` gets the show web icons value.
    func test_getShowWebIcons() async {
        appSettingsStore.disableWebIcons = true

        let value = await subject.getShowWebIcons()
        XCTAssertFalse(value)
    }

    /// `.getTimeoutAction(userId:)` returns the session timeout action.
    func test_getTimeoutAction() async throws {
        try await subject.setTimeoutAction(action: .logout, userId: "1")

        let action = try await subject.getTimeoutAction(userId: "1")
        XCTAssertEqual(action, .logout)
    }

    /// `getTwoFactorToken(email:)` gets the two-factor code associated with the email.
    func test_getTwoFactorToken() async {
        appSettingsStore.setTwoFactorToken("yay_you_win!", email: "winner@email.com")

        let value = await subject.getTwoFactorToken(email: "winner@email.com")
        XCTAssertEqual(value, "yay_you_win!")
    }

    /// `getUnsuccessfulUnlockAttempts(userId:)` gets the unsuccessful unlock attempts for the account.
    func test_getUnsuccessfulUnlockAttempts() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        appSettingsStore.unsuccessfulUnlockAttempts["1"] = 4

        let unsuccessfulUnlockAttempts = try await subject.getUnsuccessfulUnlockAttempts(userId: "1")
        XCTAssertEqual(unsuccessfulUnlockAttempts, 4)
    }

    /// `getUserHasMasterPassword(userId:)` gets whether a user has a master password for a user
    /// with a master password.
    func test_getUserHasMasterPassword() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))
        let userHasMasterPassword = try await subject.getUserHasMasterPassword()
        XCTAssertTrue(userHasMasterPassword)
    }

    /// `getUserHasMasterPassword(userId:)` gets whether a user has a master password for a TDE user
    /// without a master password.
    func test_getUserHasMasterPassword_tdeUserNoPassword() async throws {
        await subject.addAccount(
            .fixture(
                profile: .fixture(
                    userDecryptionOptions: UserDecryptionOptions(
                        hasMasterPassword: false,
                        keyConnectorOption: nil,
                        trustedDeviceOption: nil
                    ),
                    userId: "2"
                )
            )
        )
        let userHasMasterPassword = try await subject.getUserHasMasterPassword()
        XCTAssertFalse(userHasMasterPassword)
    }

    /// `getUserHasMasterPassword(userId:)` gets whether a user has a master password for a TDE user
    /// with a master password.
    func test_getUserHasMasterPassword_tdeUserWithPassword() async throws {
        await subject.addAccount(
            .fixture(
                profile: .fixture(
                    userDecryptionOptions: UserDecryptionOptions(
                        hasMasterPassword: true,
                        keyConnectorOption: nil,
                        trustedDeviceOption: nil
                    ),
                    userId: "2"
                )
            )
        )
        let userHasMasterPassword = try await subject.getUserHasMasterPassword()
        XCTAssertTrue(userHasMasterPassword)
    }

    /// `getUsernameGenerationOptions()` gets the saved username generation options for the account.
    func test_getUsernameGenerationOptions() async throws {
        let options1 = UsernameGenerationOptions(plusAddressedEmail: "user@bitwarden.com")
        let options2 = UsernameGenerationOptions(catchAllEmailDomain: "bitwarden.com")

        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        appSettingsStore.usernameGenerationOptions = [
            "1": options1,
            "2": options2,
        ]

        let fetchedOptions1 = try await subject.getUsernameGenerationOptions(userId: "1")
        XCTAssertEqual(fetchedOptions1, options1)

        let fetchedOptions2 = try await subject.getUsernameGenerationOptions(userId: "2")
        XCTAssertEqual(fetchedOptions2, options2)

        let fetchedOptionsActiveAccount = try await subject.getUsernameGenerationOptions()
        XCTAssertEqual(fetchedOptionsActiveAccount, options1)

        let fetchedOptionsNoAccount = try await subject.getUsernameGenerationOptions(userId: "-1")
        XCTAssertNil(fetchedOptionsNoAccount)
    }

    /// `.getVaultTimeout(userId:)` gets the user's vault timeout.
    func test_getVaultTimeout() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setVaultTimeout(value: .custom(20), userId: "1")
        let vaultTimeout = try await subject.getVaultTimeout(userId: "1")
        XCTAssertEqual(vaultTimeout, .custom(20))
    }

    /// `lastSyncTimePublisher()` returns a publisher for the user's last sync time.
    func test_lastSyncTimePublisher() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        var publishedValues = [Date?]()
        let publisher = try await subject.lastSyncTimePublisher()
            .sink(receiveValue: { date in
                publishedValues.append(date)
            })
        defer { publisher.cancel() }

        let date = Date(year: 2023, month: 12, day: 1)
        try await subject.setLastSyncTime(date)

        XCTAssertEqual(publishedValues, [nil, date])
    }

    /// `lastSyncTimePublisher()` gets the initial stored value if a cached sync time doesn't exist.
    func test_lastSyncTimePublisher_fetchesInitialValue() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))
        let initialSync = Date(year: 2023, month: 12, day: 1)
        appSettingsStore.lastSyncTimeByUserId["1"] = initialSync

        var publishedValues = [Date?]()
        let publisher = try await subject.lastSyncTimePublisher()
            .sink(receiveValue: { date in
                publishedValues.append(date)
            })
        defer { publisher.cancel() }

        let updatedSync = Date(year: 2023, month: 12, day: 4)
        try await subject.setLastSyncTime(updatedSync)

        XCTAssertEqual(publishedValues, [initialSync, updatedSync])
    }

    /// `connectToWatchPublisher()` returns a publisher for the user's connect to watch settings.
    func test_connectToWatchPublisher() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        var publishedValues = [ConnectToWatchValue]()
        let publisher = await subject.connectToWatchPublisher()
            .sink(receiveValue: { userId, shouldConnect in
                publishedValues.append(ConnectToWatchValue(userId: userId, shouldConnect: shouldConnect))
            })
        defer { publisher.cancel() }

        try await subject.setConnectToWatch(true)

        XCTAssertEqual(
            publishedValues,
            [
                ConnectToWatchValue(userId: "1", shouldConnect: false),
                ConnectToWatchValue(userId: "1", shouldConnect: true),
            ]
        )
    }

    /// `connectToWatchPublisher()` gets the initial stored value if a cached value doesn't exist.
    func test_connectToWatchPublisher_fetchesInitialValue() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        appSettingsStore.connectToWatchByUserId["1"] = true

        var publishedValues = [ConnectToWatchValue]()
        let publisher = await subject.connectToWatchPublisher()
            .sink(receiveValue: { userId, shouldConnect in
                publishedValues.append(ConnectToWatchValue(userId: userId, shouldConnect: shouldConnect))
            })
        defer { publisher.cancel() }

        try await subject.setConnectToWatch(false)

        XCTAssertEqual(
            publishedValues,
            [
                ConnectToWatchValue(userId: "1", shouldConnect: true),
                ConnectToWatchValue(userId: "1", shouldConnect: false),
            ]
        )
    }

    /// `connectToWatchPublisher()` uses the last connect to watch value if the user is not logged in.
    func test_connectToWatchPublisher_notLoggedIn() async throws {
        appSettingsStore.lastUserShouldConnectToWatch = true

        var publishedValues = [ConnectToWatchValue]()
        let publisher = await subject.connectToWatchPublisher()
            .sink(receiveValue: { userId, shouldConnect in
                publishedValues.append(ConnectToWatchValue(userId: userId, shouldConnect: shouldConnect))
            })
        defer { publisher.cancel() }

        XCTAssertEqual(publishedValues, [ConnectToWatchValue(userId: nil, shouldConnect: true)])
    }

    /// `getLastUserShouldConnectToWatch()` returns the value in the app settings store.
    func test_getLastUserShouldConnectToWatch() async {
        var value = await subject.getLastUserShouldConnectToWatch()
        XCTAssertFalse(value)

        appSettingsStore.lastUserShouldConnectToWatch = true

        value = await subject.getLastUserShouldConnectToWatch()
        XCTAssertTrue(value)
    }

    /// `isAuthenticated()` returns the authentication state of the user.
    func test_isAuthenticated() async throws {
        var authenticationState = await subject.isAuthenticated()
        XCTAssertFalse(authenticationState)

        await subject.addAccount(.fixture())
        try await subject.setAccountEncryptionKeys(.init(encryptedPrivateKey: "", encryptedUserKey: ""))
        authenticationState = await subject.isAuthenticated()
        XCTAssertTrue(authenticationState)
    }

    /// `logoutAccount()` clears any account data.
    func test_logoutAccount_clearAccountData() async throws { // swiftlint:disable:this function_body_length
        let account = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        await subject.addAccount(account)
        try await subject.setAccountEncryptionKeys(AccountEncryptionKeys(
            encryptedPrivateKey: "PRIVATE_KEY",
            encryptedUserKey: "USER_KEY"
        ))
        try await subject.setBiometricIntegrityState("BiometricIntegrityState")
        try await subject.setBiometricAuthenticationEnabled(true)
        try await subject.setDefaultUriMatchType(.never)
        try await subject.setDisableAutoTotpCopy(true)
        try await subject.setPasswordGenerationOptions(PasswordGenerationOptions(length: 30))
        try await dataStore.insertPasswordHistory(
            userId: "1",
            passwordHistory: PasswordHistory(password: "PASSWORD", lastUsedDate: Date())
        )
        try await dataStore.persistentContainer.viewContext.performAndSave {
            let context = self.dataStore.persistentContainer.viewContext
            _ = try CipherData(context: context, userId: "1", cipher: .fixture(id: UUID().uuidString))
            _ = try CollectionData(context: context, userId: "1", collection: .fixture())
            _ = try DomainData(
                context: context,
                userId: "1",
                domains: DomainsResponseModel(
                    equivalentDomains: nil,
                    globalEquivalentDomains: nil
                )
            )
            _ = FolderData(
                context: context,
                userId: "1",
                folder: Folder(id: "1", name: "FOLDER1", revisionDate: Date())
            )
            _ = OrganizationData(context: context, userId: "1", organization: .fixture())
            _ = PolicyData(context: context, userId: "1", policy: .fixture())
            _ = try SendData(context: context, userId: "1", send: .fixture())
        }

        try await subject.logoutAccount()

        XCTAssertEqual(appSettingsStore.biometricIntegrityStates, [:])
        XCTAssertEqual(appSettingsStore.biometricAuthenticationEnabled, [:])
        XCTAssertEqual(appSettingsStore.encryptedPrivateKeys, [:])
        XCTAssertEqual(appSettingsStore.encryptedUserKeys, [:])
        XCTAssertEqual(appSettingsStore.defaultUriMatchTypeByUserId, [:])
        XCTAssertEqual(appSettingsStore.disableAutoTotpCopyByUserId, [:])
        XCTAssertEqual(appSettingsStore.passwordGenerationOptions, [:])

        let context = dataStore.persistentContainer.viewContext
        try XCTAssertEqual(context.count(for: CipherData.fetchByUserIdRequest(userId: "1")), 0)
        try XCTAssertEqual(context.count(for: CollectionData.fetchByUserIdRequest(userId: "1")), 0)
        try XCTAssertEqual(context.count(for: DomainData.fetchByUserIdRequest(userId: "1")), 0)
        try XCTAssertEqual(context.count(for: FolderData.fetchByUserIdRequest(userId: "1")), 0)
        try XCTAssertEqual(context.count(for: OrganizationData.fetchByUserIdRequest(userId: "1")), 0)
        try XCTAssertEqual(context.count(for: PasswordHistoryData.fetchByUserIdRequest(userId: "1")), 0)
        try XCTAssertEqual(context.count(for: PolicyData.fetchByUserIdRequest(userId: "1")), 0)
        try XCTAssertEqual(context.count(for: SendData.fetchByUserIdRequest(userId: "1")), 0)
    }

    /// `logoutAccount(_:)` removes the account from the account list and sets the active account to
    /// `nil` if there are no other accounts.
    func test_logoutAccount_singleAccount() async throws {
        let account = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        await subject.addAccount(account)
        try await subject.setAccountEncryptionKeys(AccountEncryptionKeys(
            encryptedPrivateKey: "PRIVATE_KEY",
            encryptedUserKey: "USER_KEY"
        ))

        try await subject.logoutAccount(userId: "1")

        // User is removed from the state.
        let state = try XCTUnwrap(appSettingsStore.state)
        XCTAssertTrue(state.accounts.isEmpty)
        XCTAssertNil(state.activeUserId)

        // Additional user keys are removed.
        XCTAssertEqual(appSettingsStore.encryptedPrivateKeys, [:])
        XCTAssertEqual(appSettingsStore.encryptedUserKeys, [:])
    }

    /// `logoutAccount(_:)` removes the account from the account list and updates the active account
    /// to the first remaining account.
    func test_logoutAccount_multipleAccounts() async throws {
        let firstAccount = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        await subject.addAccount(firstAccount)
        try await subject.setAccountEncryptionKeys(AccountEncryptionKeys(
            encryptedPrivateKey: "1:PRIVATE_KEY",
            encryptedUserKey: "1:USER_KEY"
        ))

        let secondAccount = Account.fixture(profile: Account.AccountProfile.fixture(userId: "2"))
        await subject.addAccount(secondAccount)
        try await subject.setAccountEncryptionKeys(AccountEncryptionKeys(
            encryptedPrivateKey: "2:PRIVATE_KEY",
            encryptedUserKey: "2:USER_KEY"
        ))

        try await subject.logoutAccount(userId: "2")

        // User is removed from the state.
        let state = try XCTUnwrap(appSettingsStore.state)
        XCTAssertEqual(state.accounts, ["1": firstAccount])
        XCTAssertEqual(state.activeUserId, "1")

        // Additional user keys are removed.
        XCTAssertEqual(appSettingsStore.encryptedPrivateKeys, ["1": "1:PRIVATE_KEY"])
        XCTAssertEqual(appSettingsStore.encryptedUserKeys, ["1": "1:USER_KEY"])
    }

    /// `logoutAccount(_:)` removes an inactive account from the account list and doesn't change
    /// the active account.
    func test_logoutAccount_inactiveAccount() async throws {
        let firstAccount = Account.fixture(profile: Account.AccountProfile.fixture(userId: "1"))
        await subject.addAccount(firstAccount)
        try await subject.setAccountEncryptionKeys(AccountEncryptionKeys(
            encryptedPrivateKey: "1:PRIVATE_KEY",
            encryptedUserKey: "1:USER_KEY"
        ))

        let secondAccount = Account.fixture(profile: Account.AccountProfile.fixture(userId: "2"))
        await subject.addAccount(secondAccount)
        try await subject.setAccountEncryptionKeys(AccountEncryptionKeys(
            encryptedPrivateKey: "2:PRIVATE_KEY",
            encryptedUserKey: "2:USER_KEY"
        ))

        try await subject.logoutAccount(userId: "1")

        // User is removed from the state.
        let state = try XCTUnwrap(appSettingsStore.state)
        XCTAssertEqual(state.accounts, ["2": secondAccount])
        XCTAssertEqual(state.activeUserId, "2")

        // Additional user keys are removed.
        XCTAssertEqual(appSettingsStore.encryptedPrivateKeys, ["2": "2:PRIVATE_KEY"])
        XCTAssertEqual(appSettingsStore.encryptedUserKeys, ["2": "2:USER_KEY"])
    }

    /// `pinKeyEncryptedUserKey()` returns the pin key encrypted user key.
    func test_pinKeyEncryptedUserKey() async throws {
        let account = Account.fixture()
        await subject.addAccount(account)

        try await subject.setPinKeys(
            pinKeyEncryptedUserKey: "123",
            pinProtectedUserKey: "321",
            requirePasswordAfterRestart: true
        )

        let pinKeyEncryptedUserKey = try await subject.pinKeyEncryptedUserKey()
        let pinProtectedUserKey = await subject.accountVolatileData["1"]?.pinProtectedUserKey

        XCTAssertEqual(pinKeyEncryptedUserKey, "123")
        XCTAssertEqual(pinProtectedUserKey, "321")
    }

    /// `pinProtectedUserKey(userId:)` returns the pin protected user key.
    func test_pinProtectedUserKey() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))
        appSettingsStore.pinProtectedUserKey["1"] = "123"
        let pin = try await subject.pinProtectedUserKey(userId: "1")
        XCTAssertEqual(pin, "123")
    }

    /// `rememberedOrgIdentifier` gets and sets the value as expected.
    func test_rememberedOrgIdentifier() {
        // Getting the value should get the value from the app settings store.
        appSettingsStore.rememberedOrgIdentifier = "ImALumberjack"
        XCTAssertEqual(subject.rememberedOrgIdentifier, "ImALumberjack")

        // Setting the value should update the value in the app settings store.
        subject.rememberedOrgIdentifier = "AndImOk"
        XCTAssertEqual(appSettingsStore.rememberedOrgIdentifier, "AndImOk")
    }

    /// `getShouldTrustDevice` gets the value as expected.
    func test_getShouldTrustDevice() async {
        appSettingsStore.shouldTrustDevice["1"] = true
        let result = await subject.getShouldTrustDevice(userId: "1")
        XCTAssertTrue(result == true)
    }

    /// `setAccountEncryptionKeys(_:userId:)` sets the encryption keys for the user account.
    func test_setAccountEncryptionKeys() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))
        await subject.addAccount(.fixture(profile: .fixture(userId: "2")))

        let encryptionKeys = AccountEncryptionKeys(
            encryptedPrivateKey: "1:PRIVATE_KEY",
            encryptedUserKey: "1:USER_KEY"
        )
        try await subject.setAccountEncryptionKeys(encryptionKeys, userId: "1")

        let otherEncryptionKeys = AccountEncryptionKeys(
            encryptedPrivateKey: "2:PRIVATE_KEY",
            encryptedUserKey: "2:USER_KEY"
        )
        try await subject.setAccountEncryptionKeys(otherEncryptionKeys)

        XCTAssertEqual(
            appSettingsStore.encryptedPrivateKeys,
            [
                "1": "1:PRIVATE_KEY",
                "2": "2:PRIVATE_KEY",
            ]
        )
        XCTAssertEqual(
            appSettingsStore.encryptedUserKeys,
            [
                "1": "1:USER_KEY",
                "2": "2:USER_KEY",
            ]
        )
    }

    /// `setActiveAccount(userId: )` returns without action if there are no accounts
    func test_setActiveAccount_noAccounts() async throws {
        let storeState = await subject.appSettingsStore.state
        XCTAssertNil(storeState)
    }

    /// `setActiveAccount(userId: )` fails if there are no matching accounts
    func test_setActiveAccount_noMatch() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        await assertAsyncThrows(error: StateServiceError.noAccounts) {
            try await subject.setActiveAccount(userId: "2")
        }
    }

    /// `setActiveAccount(userId: )` succeeds if there is a matching account
    func test_setActiveAccount_match_single() async throws {
        let account1 = Account.fixture(profile: .fixture(userId: "1"))
        await subject.addAccount(account1)

        var active = try await subject.getActiveAccount()
        XCTAssertEqual(active, account1)
        try await subject.setActiveAccount(userId: "1")
        active = try await subject.getActiveAccount()
        XCTAssertEqual(active, account1)
    }

    /// `setAddSitePromptShown(_:)` sets whether the autofill info prompt has been shown.
    func test_setAddSitePromptShown() async {
        await subject.setAddSitePromptShown(true)
        XCTAssertTrue(appSettingsStore.addSitePromptShown)

        await subject.setAddSitePromptShown(false)
        XCTAssertFalse(appSettingsStore.addSitePromptShown)
    }

    /// `setAllowSyncOnRefresh(_:userId:)` sets the allow sync on refresh value for a user.
    func test_setAllowSyncOnRefresh() async throws {
        await subject.addAccount(.fixture())

        try await subject.setAllowSyncOnRefresh(true)
        XCTAssertEqual(appSettingsStore.allowSyncOnRefreshes["1"], true)
    }

    /// `setBiometricAuthenticationEnabled(isEnabled:)` sets biometric unlock preference for the default user.
    func test_setBiometricAuthenticationEnabled_default() async throws {
        await subject.addAccount(.fixture())
        try await subject.setBiometricAuthenticationEnabled(true)
        XCTAssertTrue(appSettingsStore.isBiometricAuthenticationEnabled(userId: "1"))
        try await subject.setBiometricAuthenticationEnabled(false)
        XCTAssertFalse(appSettingsStore.isBiometricAuthenticationEnabled(userId: "1"))
    }

    /// `setBiometricAuthenticationEnabled(isEnabled:, userId:)` throws with no userID and no active user.
    func test_setBiometricAuthenticationEnabled_error() async throws {
        await assertAsyncThrows(error: StateServiceError.noActiveAccount) {
            try await subject.setBiometricAuthenticationEnabled(true)
        }
    }

    /// `setBiometricAuthenticationEnabled(:)` sets biometric unlock preference for a user id.
    func test_setBiometricAuthenticationEnabled_userID() async throws {
        await subject.addAccount(.fixture())
        try await subject.setBiometricAuthenticationEnabled(true)
        XCTAssertTrue(appSettingsStore.isBiometricAuthenticationEnabled(userId: "1"))
        try await subject.setBiometricAuthenticationEnabled(false)
        XCTAssertFalse(appSettingsStore.isBiometricAuthenticationEnabled(userId: "1"))
    }

    /// `setBiometricIntegrityState(:)` sets biometric unlock preference for a user id.
    func test_setBiometricIntegrityState_userID() async throws {
        await subject.addAccount(.fixture())
        try await subject.setBiometricIntegrityState("SetStateValue")
        XCTAssertEqual(
            appSettingsStore.biometricIntegrityState(userId: "1"),
            "SetStateValue"
        )
        XCTAssertNil(appSettingsStore.biometricIntegrityState(userId: "2"))
        try await subject.setBiometricIntegrityState(nil)
        XCTAssertNil(appSettingsStore.biometricIntegrityState(userId: "1"))
    }

    /// `setClearClipboardValue(_:userId:)` sets the clear clipboard value for a user.
    func test_setClearClipboardValue() async throws {
        await subject.addAccount(.fixture())

        try await subject.setClearClipboardValue(.thirtySeconds)
        XCTAssertEqual(appSettingsStore.clearClipboardValues["1"], .thirtySeconds)
    }

    /// `setConfig(_:)` sets the config values.
    func test_setConfig() async {
        let model = ConfigResponseModel(
            version: "1.2.3.4",
            gitHash: "1234",
            server: nil,
            environment: nil,
            featureStates: [:]
        )
        await subject.setConfig(model)
        XCTAssertEqual(appSettingsStore.config, model)
    }

    /// `setConnectToWatch(_:userId:)` sets the connect to watch value for a user.
    func test_setConnectToWatch() async throws {
        await subject.addAccount(.fixture())

        try await subject.setConnectToWatch(true)
        XCTAssertTrue(appSettingsStore.connectToWatch(userId: "1"))
        XCTAssertTrue(appSettingsStore.lastUserShouldConnectToWatch)
    }

    /// `setLastSyncTime(_:userId:)` sets the last sync time for a user.
    func test_setLastSyncTime() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        let date = Date(year: 2023, month: 12, day: 1)
        try await subject.setLastSyncTime(date)
        XCTAssertEqual(appSettingsStore.lastSyncTimeByUserId["1"], date)

        let date2 = Date(year: 2023, month: 12, day: 2)
        try await subject.setLastSyncTime(date2, userId: "1")
        XCTAssertEqual(appSettingsStore.lastSyncTimeByUserId["1"], date2)
    }

    /// `setDefaultUriMatchType(_:userId:)` sets the default URI match type value for a user.
    func test_setDefaultUriMatchType() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setDefaultUriMatchType(.startsWith, userId: "1")
        XCTAssertEqual(appSettingsStore.defaultUriMatchTypeByUserId["1"], .startsWith)

        try await subject.setDefaultUriMatchType(.regularExpression, userId: "1")
        XCTAssertEqual(appSettingsStore.defaultUriMatchTypeByUserId["1"], .regularExpression)
    }

    /// `setDisableAutoTotpCopy(_:userId:)` sets the disable auto-copy TOTP value for a user.
    func test_setDisableAutoTotpCopy() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setDisableAutoTotpCopy(true, userId: "1")
        XCTAssertEqual(appSettingsStore.disableAutoTotpCopyByUserId["1"], true)

        try await subject.setDisableAutoTotpCopy(false, userId: "1")
        XCTAssertEqual(appSettingsStore.disableAutoTotpCopyByUserId["1"], false)
    }

    /// `setActiveAccount(userId: )` succeeds if there is a matching account
    func test_setActiveAccount_match_multi() async throws {
        let account1 = Account.fixture(profile: .fixture(userId: "1"))
        let account2 = Account.fixture(profile: .fixture(userId: "2"))
        await subject.addAccount(account1)
        await subject.addAccount(account2)

        var active = try await subject.getActiveAccount()
        XCTAssertEqual(active, account2)
        try await subject.setActiveAccount(userId: "1")
        active = try await subject.getActiveAccount()
        XCTAssertEqual(active, account1)
    }

    /// `setForcePasswordResetReason(_:)` sets the force password reset reason.
    func test_setForcePasswordResetReason() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))
        await subject.addAccount(.fixture(profile: .fixture(userId: "2")))

        try await subject.setForcePasswordResetReason(.adminForcePasswordReset)
        XCTAssertNil(appSettingsStore.state?.accounts["1"]?.profile.forcePasswordResetReason)
        XCTAssertEqual(
            appSettingsStore.state?.accounts["2"]?.profile.forcePasswordResetReason,
            .adminForcePasswordReset
        )

        try await subject.setForcePasswordResetReason(nil)
        XCTAssertNil(appSettingsStore.state?.accounts["1"]?.profile.forcePasswordResetReason)
        XCTAssertNil(appSettingsStore.state?.accounts["2"]?.profile.forcePasswordResetReason)
    }

    /// `setLastActiveTime(userId:)` sets the user's last active time.
    func test_setLastActiveTime() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setLastActiveTime(Date())

        XCTAssertEqual(
            appSettingsStore.lastActiveTime["1"]!.timeIntervalSince1970,
            Date().timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    /// `setLoginRequest()` sets the pending login requests.
    func test_setLoginRequest() async {
        let loginRequest = LoginRequestNotification(id: "1", userId: "10")
        await subject.setLoginRequest(loginRequest)
        XCTAssertEqual(appSettingsStore.loginRequest, loginRequest)
    }

    /// `setMasterPasswordHash(_:)` sets the master password hash for a user.
    func test_setMasterPasswordHash() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setMasterPasswordHash("abcd")
        XCTAssertEqual(appSettingsStore.masterPasswordHashes, ["1": "abcd"])

        try await subject.setMasterPasswordHash("1234", userId: "1")
        XCTAssertEqual(appSettingsStore.masterPasswordHashes, ["1": "1234"])
    }

    /// `setNotificationsLastRegistrationDate(_:)` sets the last notifications registration date for a user.
    func test_setNotificationsLastRegistrationDate() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setNotificationsLastRegistrationDate(Date(year: 2024, month: 1, day: 1))
        XCTAssertEqual(appSettingsStore.notificationsLastRegistrationDates["1"], Date(year: 2024, month: 1, day: 1))
    }

    /// `setPasswordGenerationOptions` sets the password generation options for an account.
    func test_setPasswordGenerationOptions() async throws {
        let options1 = PasswordGenerationOptions(length: 30)
        let options2 = PasswordGenerationOptions(length: 50)

        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))
        try await subject.setPasswordGenerationOptions(options1)
        try await subject.setPasswordGenerationOptions(options2, userId: "2")

        XCTAssertEqual(appSettingsStore.passwordGenerationOptions["1"], options1)
        XCTAssertEqual(appSettingsStore.passwordGenerationOptions["2"], options2)
    }

    /// `setPinKeys(encryptedPin:pinProtectedUserKey:requirePasswordAfterRestart:)` sets pin keys for an account.
    func test_setPinKeys() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setPinKeys(
            pinKeyEncryptedUserKey: "123",
            pinProtectedUserKey: "123",
            requirePasswordAfterRestart: false
        )
        XCTAssertEqual(appSettingsStore.pinProtectedUserKey["1"], "123")
        XCTAssertEqual(appSettingsStore.pinKeyEncryptedUserKey["1"], "123")
    }

    /// `setPreAuthEnvironmentUrls` saves the pre-auth URLs.
    func test_setPreAuthEnvironmentUrls() async {
        let urls = EnvironmentUrlData(base: .example)
        await subject.setPreAuthEnvironmentUrls(urls)
        XCTAssertEqual(appSettingsStore.preAuthEnvironmentUrls, urls)
    }

    /// `setShouldTrustDevice` saves the should trust device value.
    func test_setShouldTrustDevice() async {
        await subject.setShouldTrustDevice(true, userId: "1")
        XCTAssertTrue(appSettingsStore.shouldTrustDevice["1"] == true)
    }

    /// `setShowWebIcons` saves the show web icons value..
    func test_setShowWebIcons() async {
        await subject.setShowWebIcons(false)
        XCTAssertTrue(appSettingsStore.disableWebIcons)
    }

    /// `setTwoFactorToken(_:email:)` sets the two-factor code for the email.
    func test_setTwoFactorToken() async {
        await subject.setTwoFactorToken("yay_you_win!", email: "winner@email.com")
        XCTAssertEqual(appSettingsStore.twoFactorToken(email: "winner@email.com"), "yay_you_win!")
    }

    /// `setUnsuccessfulUnlockAttempts(userId:)` sets the unsuccessful unlock attempts for the account.
    func test_setUnsuccessfulUnlockAttempts() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setUnsuccessfulUnlockAttempts(3, userId: "1")

        XCTAssertEqual(appSettingsStore.unsuccessfulUnlockAttempts["1"], 3)
    }

    /// `setUsernameGenerationOptions` sets the username generation options for an account.
    func test_setUsernameGenerationOptions() async throws {
        let options1 = UsernameGenerationOptions(plusAddressedEmail: "user@bitwarden.com")
        let options2 = UsernameGenerationOptions(catchAllEmailDomain: "bitwarden.com")

        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setUsernameGenerationOptions(options1)
        try await subject.setUsernameGenerationOptions(options2, userId: "2")

        XCTAssertEqual(appSettingsStore.usernameGenerationOptions["1"], options1)
        XCTAssertEqual(appSettingsStore.usernameGenerationOptions["2"], options2)
    }

    /// `.setsetUserHasMasterPassword()` sets the user has having master password set .
    func test_setUserHasMasterPassword() async throws {
        let account1 = Account.fixtureWithTdeNoPassword()
        await subject.addAccount(account1)

        XCTAssertFalse(appSettingsStore.state?.accounts["1"]?.profile.userDecryptionOptions?.hasMasterPassword ?? false)

        try await subject.setUserHasMasterPassword()

        XCTAssertNotEqual(appSettingsStore.state?.accounts["1"], account1)
        XCTAssertTrue(appSettingsStore.state?.accounts["1"]?.profile.userDecryptionOptions?.hasMasterPassword ?? false)
    }

    /// `.setActiveAccount(userId:)` sets the action that occurs when there's a session timeout.
    func test_setTimeoutAction() async throws {
        let account = Account.fixture()
        let userId = account.profile.userId

        try await subject.setTimeoutAction(action: .logout, userId: userId)
        XCTAssertEqual(appSettingsStore.timeoutAction[userId], 1)
    }

    /// `.setTimeoutAction(userId:)` sets the timeout action when there is no user ID passed.
    func test_setTimeoutAction_noUserId() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setTimeoutAction(action: .logout, userId: nil)
        XCTAssertEqual(appSettingsStore.timeoutAction["1"], 1)
    }

    /// `.setVaultTimeout(value:userId:)` sets the vault timeout value for the user.
    func test_setVaultTimeout() async throws {
        await subject.addAccount(.fixture(profile: .fixture(userId: "1")))

        try await subject.setVaultTimeout(value: .custom(20))

        XCTAssertEqual(appSettingsStore.vaultTimeout["1"], 20)
    }

    /// `showWebIconsPublisher()` returns a publisher for the show web icons value.
    func test_showWebIconsPublisher() async {
        var publishedValues = [Bool]()
        let publisher = await subject.showWebIconsPublisher()
            .sink(receiveValue: { date in
                publishedValues.append(date)
            })
        defer { publisher.cancel() }

        await subject.setShowWebIcons(false)

        XCTAssertEqual(publishedValues, [true, false])
    }

    /// `updateProfile(from:userId:)` updates the user's profile from the profile response.
    func test_updateProfile() async throws {
        await subject.addAccount(
            .fixture(
                profile: .fixture(
                    avatarColor: nil,
                    email: "user@bitwarden.com",
                    emailVerified: false,
                    hasPremiumPersonally: false,
                    name: "User",
                    stamp: "stamp",
                    userId: "1"
                )
            )
        )

        await subject.updateProfile(
            from: .fixture(
                avatarColor: "175DDC",
                email: "other@bitwarden.com",
                emailVerified: true,
                name: "Other",
                premium: true,
                securityStamp: "new stamp"
            ),
            userId: "1"
        )

        let updatedAccount = try await subject.getActiveAccount()
        XCTAssertEqual(
            updatedAccount,
            .fixture(
                profile: .fixture(
                    avatarColor: "175DDC",
                    email: "other@bitwarden.com",
                    emailVerified: true,
                    hasPremiumPersonally: true,
                    name: "Other",
                    stamp: "new stamp",
                    userId: "1"
                )
            )
        )
    }
}

private struct ConnectToWatchValue: Equatable {
    let userId: String?
    let shouldConnect: Bool
} // swiftlint:disable:this file_length
