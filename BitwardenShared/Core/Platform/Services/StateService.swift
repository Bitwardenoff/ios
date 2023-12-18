import Combine

// swiftlint:disable file_length

// MARK: - StateService

/// A protocol for a `StateService` which manages the state of the accounts in the app.
///
protocol StateService: AnyObject {
    /// Adds a new account to the app's state after a successful login.
    ///
    /// - Parameter account: The `Account` to add.
    ///
    func addAccount(_ account: Account) async

    /// Deletes the current active account.
    ///
    func deleteAccount() async throws

    /// Gets the account encryptions keys for an account.
    ///
    /// - Parameter userId: The user ID of the account. Defaults to the active account if `nil`.
    /// - Returns: The account encryption keys.
    ///
    func getAccountEncryptionKeys(userId: String?) async throws -> AccountEncryptionKeys

    /// Gets all accounts.
    ///
    /// - Returns: The known user accounts.
    ///
    func getAccounts() async throws -> [Account]

    /// Gets the account id or the active account id for a possible id.
    /// - Parameter userId: The possible user Id of an account
    /// - Returns: The user account id or the active id
    ///
    func getAccountIdOrActiveId(userId: String?) async throws -> String

    /// Gets the active account.
    ///
    /// - Returns: The active user account.
    ///
    func getActiveAccount() async throws -> Account

    /// Gets the active account id.
    ///
    /// - Returns: The active user account id.
    ///
    func getActiveAccountId() async throws -> String

    /// Gets the environment URLs for a user ID.
    ///
    /// - Parameter userId: The user ID associated with the environment URLs.
    /// - Returns: The user's environment URLs.
    ///
    func getEnvironmentUrls(userId: String?) async throws -> EnvironmentUrlData?

    /// Gets the password generation options for a user ID.
    ///
    /// - Parameter userId: The user ID associated with the password generation options.
    /// - Returns: The password generation options for the user ID.
    ///
    func getPasswordGenerationOptions(userId: String?) async throws -> PasswordGenerationOptions?

    /// Gets the environment URLs used by the app prior to the user authenticating.
    ///
    /// - Returns: The environment URLs used prior to user authentication.
    ///
    func getPreAuthEnvironmentUrls() async -> EnvironmentUrlData?

    /// Gets the username generation options for a user ID.
    ///
    /// - Parameter userId: The user ID associated with the username generation options.
    /// - Returns: The username generation options for the user ID.
    ///
    func getUsernameGenerationOptions(userId: String?) async throws -> UsernameGenerationOptions?

    /// Logs the user out of an account.
    ///
    /// - Parameter userId: The user ID of the account to log out of. Defaults to the active
    ///     account if `nil`.
    ///
    func logoutAccount(userId: String?) async throws

    /// Sets the account encryption keys for an account.
    ///
    /// - Parameters:
    ///   - encryptionKeys:  The account encryption keys.
    ///   - userId: The user ID of the account. Defaults to the active account if `nil`.
    ///
    func setAccountEncryptionKeys(_ encryptionKeys: AccountEncryptionKeys, userId: String?) async throws

    /// Sets the active account.
    /// - Parameter userId: The user Id of the account to set as active
    /// - Returns: The active user account.
    ///
    func setActiveAccount(userId: String) async throws

    /// Sets the password generation options for a user ID.
    ///
    /// - Parameters:
    ///   - options: The user's password generation options.
    ///   - userId: The user ID associated with the password generation options.
    ///
    func setPasswordGenerationOptions(_ options: PasswordGenerationOptions?, userId: String?) async throws

    /// Sets the environment URLs used prior to user authentication.
    ///
    /// - Parameter urls: The environment URLs used prior to user authentication.
    ///
    func setPreAuthEnvironmentUrls(_ urls: EnvironmentUrlData) async

    /// Sets a new access and refresh token for an account.
    ///
    /// - Parameters:
    ///   - accessToken: The account's updated access token.
    ///   - refreshToken: The account's updated refresh token.
    ///   - userId: The user ID of the account. Defaults to the active account if `nil`.
    ///
    func setTokens(accessToken: String, refreshToken: String, userId: String?) async throws

    /// Sets the username generation options for a user ID.
    ///
    /// - Parameters:
    ///   - options: The user's username generation options.
    ///   - userId: The user ID associated with the username generation options.
    ///
    func setUsernameGenerationOptions(_ options: UsernameGenerationOptions?, userId: String?) async throws

    // MARK: Publishers

    /// A publisher for the active account id
    ///
    /// - Returns: The userId `String` of the active account
    ///
    func activeAccountIdPublisher() async -> AsyncPublisher<AnyPublisher<String?, Never>>
}

extension StateService {
    /// Gets the account encryptions keys for the active account.
    ///
    /// - Returns: The account encryption keys.
    ///
    func getAccountEncryptionKeys() async throws -> AccountEncryptionKeys {
        try await getAccountEncryptionKeys(userId: nil)
    }

    /// Gets the environment URLs for the active account.
    ///
    /// - Returns: The environment URLs for the active account.
    ///
    func getEnvironmentUrls() async throws -> EnvironmentUrlData? {
        try await getEnvironmentUrls(userId: nil)
    }

    /// Gets the password generation options for the active account.
    ///
    /// - Returns: The password generation options for the user ID.
    ///
    func getPasswordGenerationOptions() async throws -> PasswordGenerationOptions? {
        try await getPasswordGenerationOptions(userId: nil)
    }

    /// Gets the username generation options for the active account.
    ///
    /// - Returns: The username generation options for the user ID.
    ///
    func getUsernameGenerationOptions() async throws -> UsernameGenerationOptions? {
        try await getUsernameGenerationOptions(userId: nil)
    }

    /// Logs the user out of the active account.
    ///
    func logoutAccount() async throws {
        try await logoutAccount(userId: nil)
    }

    /// Sets the account encryption keys for the active account.
    ///
    /// - Parameters:
    ///   - encryptionKeys: The account encryption keys.
    ///
    func setAccountEncryptionKeys(_ encryptionKeys: AccountEncryptionKeys) async throws {
        try await setAccountEncryptionKeys(encryptionKeys, userId: nil)
    }

    /// Sets the password generation options for the active account.
    ///
    /// - Parameters options: The user's password generation options.
    ///
    func setPasswordGenerationOptions(_ options: PasswordGenerationOptions?) async throws {
        try await setPasswordGenerationOptions(options, userId: nil)
    }

    /// Sets a new access and refresh token for the active account.
    ///
    /// - Parameters:
    ///   - accessToken: The account's updated access token.
    ///   - refreshToken: The account's updated refresh token.
    ///
    func setTokens(accessToken: String, refreshToken: String) async throws {
        try await setTokens(accessToken: accessToken, refreshToken: refreshToken, userId: nil)
    }

    /// Sets the username generation options for the active account.
    ///
    /// - Parameters options: The user's username generation options.
    ///
    func setUsernameGenerationOptions(_ options: UsernameGenerationOptions?) async throws {
        try await setUsernameGenerationOptions(options, userId: nil)
    }
}

// MARK: - StateServiceError

/// The errors thrown from a `StateService`.
///
enum StateServiceError: Error {
    /// There are no known accounts.
    case noAccounts

    /// There isn't an active account.
    case noActiveAccount
}

// MARK: - DefaultStateService

/// A default implementation of `StateService`.
///
actor DefaultStateService: StateService {
    // MARK: Properties

    /// The service that persists app settings.
    let appSettingsStore: AppSettingsStore

    /// The data store that handles performing data requests.
    let dataStore: DataStore

    // MARK: Initialization

    /// Initialize a `DefaultStateService`.
    ///
    /// - Parameters:
    ///   - appSettingsStore: The service that persists app settings.
    ///   - dataStore: The data store that handles performing data requests.
    ///
    init(appSettingsStore: AppSettingsStore, dataStore: DataStore) {
        self.appSettingsStore = appSettingsStore
        self.dataStore = dataStore
    }

    // MARK: Methods

    func addAccount(_ account: Account) async {
        var state = appSettingsStore.state ?? State()
        defer { appSettingsStore.state = state }

        state.accounts[account.profile.userId] = account
        state.activeUserId = account.profile.userId
    }

    func deleteAccount() async throws {
        try await logoutAccount()
    }

    func getAccountEncryptionKeys(userId: String?) async throws -> AccountEncryptionKeys {
        let userId = try userId ?? getActiveAccountUserId()
        guard let encryptedPrivateKey = appSettingsStore.encryptedPrivateKey(userId: userId),
              let encryptedUserKey = appSettingsStore.encryptedUserKey(userId: userId)
        else {
            throw StateServiceError.noActiveAccount
        }
        return AccountEncryptionKeys(
            encryptedPrivateKey: encryptedPrivateKey,
            encryptedUserKey: encryptedUserKey
        )
    }

    func getAccountIdOrActiveId(userId: String?) throws -> String {
        guard let accounts = appSettingsStore.state?.accounts else {
            throw StateServiceError.noAccounts
        }
        if let userId {
            guard accounts.contains(where: { $0.value.profile.userId == userId }) else {
                throw StateServiceError.noAccounts
            }
            return userId
        }
        return try getActiveAccountId()
    }

    func getActiveAccountId() throws -> String {
        try getActiveAccount().profile.userId
    }

    func getAccounts() throws -> [Account] {
        guard let accounts = appSettingsStore.state?.accounts else {
            throw StateServiceError.noAccounts
        }
        return Array(accounts.values)
    }

    func getActiveAccount() throws -> Account {
        guard let activeAccount = appSettingsStore.state?.activeAccount else {
            throw StateServiceError.noActiveAccount
        }
        return activeAccount
    }

    func getEnvironmentUrls(userId: String?) async throws -> EnvironmentUrlData? {
        let userId = try userId ?? getActiveAccountUserId()
        return appSettingsStore.state?.accounts[userId]?.settings.environmentUrls
    }

    func getPasswordGenerationOptions(userId: String?) async throws -> PasswordGenerationOptions? {
        let userId = try userId ?? getActiveAccountUserId()
        return appSettingsStore.passwordGenerationOptions(userId: userId)
    }

    func getPreAuthEnvironmentUrls() async -> EnvironmentUrlData? {
        appSettingsStore.preAuthEnvironmentUrls
    }

    func getUsernameGenerationOptions(userId: String?) async throws -> UsernameGenerationOptions? {
        let userId = try userId ?? getActiveAccountUserId()
        return appSettingsStore.usernameGenerationOptions(userId: userId)
    }

    func logoutAccount(userId: String?) async throws {
        guard var state = appSettingsStore.state else { return }
        defer { appSettingsStore.state = state }

        let userId = try userId ?? getActiveAccountUserId()
        state.accounts.removeValue(forKey: userId)
        if state.activeUserId == userId {
            // Find the next account to make the active account.
            state.activeUserId = state.accounts.first?.key
        }

        appSettingsStore.setEncryptedPrivateKey(key: nil, userId: userId)
        appSettingsStore.setEncryptedUserKey(key: nil, userId: userId)
        appSettingsStore.setPasswordGenerationOptions(nil, userId: userId)

        try await dataStore.deleteDataForUser(userId: userId)
    }

    func setAccountEncryptionKeys(_ encryptionKeys: AccountEncryptionKeys, userId: String?) async throws {
        let userId = try userId ?? getActiveAccountUserId()
        appSettingsStore.setEncryptedPrivateKey(key: encryptionKeys.encryptedPrivateKey, userId: userId)
        appSettingsStore.setEncryptedUserKey(key: encryptionKeys.encryptedUserKey, userId: userId)
    }

    func setActiveAccount(userId: String) async throws {
        guard var state = appSettingsStore.state else { return }
        defer { appSettingsStore.state = state }

        guard state.accounts
            .contains(where: { $0.key == userId }) else { throw StateServiceError.noAccounts }
        state.activeUserId = userId
    }

    func setPasswordGenerationOptions(_ options: PasswordGenerationOptions?, userId: String?) async throws {
        let userId = try userId ?? getActiveAccountUserId()
        appSettingsStore.setPasswordGenerationOptions(options, userId: userId)
    }

    func setPreAuthEnvironmentUrls(_ urls: EnvironmentUrlData) async {
        appSettingsStore.preAuthEnvironmentUrls = urls
    }

    func setTokens(accessToken: String, refreshToken: String, userId: String?) async throws {
        guard var state = appSettingsStore.state,
              let userId = userId ?? state.activeUserId
        else {
            throw StateServiceError.noActiveAccount
        }

        state.accounts[userId]?.tokens = Account.AccountTokens(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
        appSettingsStore.state = state
    }

    func setUsernameGenerationOptions(_ options: UsernameGenerationOptions?, userId: String?) async throws {
        let userId = try userId ?? getActiveAccountUserId()
        appSettingsStore.setUsernameGenerationOptions(options, userId: userId)
    }

    // MARK: Publishers

    func activeAccountIdPublisher() -> AsyncPublisher<AnyPublisher<String?, Never>> {
        appSettingsStore.activeAccountIdPublisher()
    }

    // MARK: Private

    /// Returns the user ID for the active account.
    ///
    /// - Returns: The user ID for the active account.
    ///
    private func getActiveAccountUserId() throws -> String {
        guard let activeUserId = appSettingsStore.state?.activeUserId else {
            throw StateServiceError.noActiveAccount
        }
        return activeUserId
    }
}
