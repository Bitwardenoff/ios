import BitwardenSdk
import Foundation

/// A protocol for an `AuthRepository` which manages access to the data needed by the UI layer.
///
protocol AuthRepository: AnyObject {
    // MARK: Methods

    /// Enables or disables biometric unlock for a user.
    ///
    /// - Parameters:
    ///   - enabled: Whether or not the the user wants biometric auth enabled.
    ///     If `true`, the userAuthKey is stored to the keychain and the user preference is set to false.
    ///     If `false`, any userAuthKey is deleted from the keychain and the user preference is set to false.
    ///   - userId: The user Id to be configured.
    ///
    func allowBioMetricUnlock(_ enabled: Bool, userId: String?) async throws

    /// Deletes the user's account.
    ///
    /// - Parameter passwordText: The password entered by the user, which is used to verify
    /// their identify before deleting the account.
    ///
    func deleteAccount(passwordText: String) async throws

    /// Gets all accounts.
    ///
    /// - Returns: The known user accounts as `[ProfileSwitcherItem]`.
    ///
    func getAccounts() async throws -> [ProfileSwitcherItem]

    /// Gets the active account.
    ///
    /// - Returns: The active user account as a `ProfileSwitcherItem`.
    ///
    func getActiveAccount() async throws -> ProfileSwitcherItem

    /// Gets the account for a `ProfileSwitcherItem`.
    ///
    /// - Parameter userId: The user Id to be mapped to an account.
    /// - Returns: The user account.
    ///
    func getAccount(for userId: String) async throws -> Account

    /// Gets the account's unique fingerprint phrase.
    ///
    /// - Parameter userId: The user Id used in generating a fingerprint phrase.
    /// - Returns: The account fingerprint phrase.
    ///
    func getFingerprintPhrase(userId: String?) async throws -> String

    /// Locks the user's vault and clears decrypted data from memory.
    ///
    ///  - Parameter userId: The userId of the account to lock.
    ///     Defaults to active account if nil.
    ///
    func lockVault(userId: String?) async

    /// Logs the user out of the specified account.
    ///
    /// - Parameter userId: The user ID of the account to log out of.
    ///
    func logout(userId: String?) async throws

    /// Calculates the password strength of a password.
    ///
    /// - Parameters:
    ///   - email: The user's email.
    ///   - password: The user's password.
    /// - Returns: The password strength of the password.
    ///
    func passwordStrength(email: String, password: String) async -> UInt8

    /// Sets the active account by User Id.
    ///
    /// - Parameter userId: The user Id to be set as active.
    /// - Returns: The new active account.
    ///
    func setActiveAccount(userId: String) async throws -> Account

    /// Attempts to unlock the user's vault with their master password.
    ///
    /// - Parameter password: The user's master password to unlock the vault.
    ///
    func unlockVault(password: String) async throws

    /// Attempts to unlock the user's vault with biometrics.
    ///
    func unlockVaultWithBiometrics() async throws
}

extension AuthRepository {
    /// Logs the user out of the active account.
    ///
    func logout() async throws {
        try await logout(userId: nil)
    }
}

// MARK: - DefaultAuthRepository

/// A default implementation of an `AuthRepository`.
///
class DefaultAuthRepository {
    // MARK: Properties

    /// The services used by the application to make account related API requests.
    private let accountAPIService: AccountAPIService

    /// The service used that handles some of the auth logic.
    private let authService: AuthService

    /// The service to use system Biometrics for vault unlock.
    let biometricsService: BiometricsService

    /// The client used by the application to handle auth related encryption and decryption tasks.
    private let clientAuth: ClientAuthProtocol

    /// The client used by the application to handle encryption and decryption setup tasks.
    private let clientCrypto: ClientCryptoProtocol

    /// The client used by the application to handle account fingerprint phrase generation.
    private let clientPlatform: ClientPlatformProtocol

    /// The service used by the application to manage the environment settings.
    private let environmentService: EnvironmentService

    /// The service used to manage syncing and updates to the user's organizations.
    private let organizationService: OrganizationService

    /// The service used by the application to manage account state.
    private let stateService: StateService

    /// The service used by the application to manage vault access.
    private let vaultTimeoutService: VaultTimeoutService

    // MARK: Initialization

    /// Initialize a `DefaultAuthRepository`.
    ///
    /// - Parameters:
    ///   - accountAPIService: The services used by the application to make account related API requests.
    ///   - authService: The service used that handles some of the auth logic.
    ///   - biometricsService: The service to use system Biometrics for vault unlock.
    ///   - clientAuth: The client used by the application to handle auth related encryption and decryption tasks.
    ///   - clientCrypto: The client used by the application to handle encryption and decryption setup tasks.
    ///   - clientPlatform: The client used by the application to handle generating account fingerprints.
    ///   - environmentService: The service used by the application to manage the environment settings.
    ///   - organizationService: The service used to manage syncing and updates to the user's organizations.
    ///   - stateService: The service used by the application to manage account state.
    ///   - vaultTimeoutService: The service used by the application to manage vault access.
    ///
    init(
        accountAPIService: AccountAPIService,
        authService: AuthService,
        biometricsService: BiometricsService,
        clientAuth: ClientAuthProtocol,
        clientCrypto: ClientCryptoProtocol,
        clientPlatform: ClientPlatformProtocol,
        environmentService: EnvironmentService,
        organizationService: OrganizationService,
        stateService: StateService,
        vaultTimeoutService: VaultTimeoutService
    ) {
        self.accountAPIService = accountAPIService
        self.authService = authService
        self.biometricsService = biometricsService
        self.clientAuth = clientAuth
        self.clientCrypto = clientCrypto
        self.clientPlatform = clientPlatform
        self.environmentService = environmentService
        self.organizationService = organizationService
        self.stateService = stateService
        self.vaultTimeoutService = vaultTimeoutService
    }
}

// MARK: - AuthRepository

extension DefaultAuthRepository: AuthRepository {
    func allowBioMetricUnlock(_ enabled: Bool, userId: String?) async throws {
        try await biometricsService.setBiometricUnlockKey(
            authKey: enabled ? clientCrypto.getUserEncryptionKey() : nil,
            for: userId
        )
    }

    func deleteAccount(passwordText: String) async throws {
        let hashedPassword = try await authService.hashPassword(password: passwordText, purpose: .serverAuthorization)

        _ = try await accountAPIService.deleteAccount(
            body: DeleteAccountRequestModel(masterPasswordHash: hashedPassword)
        )

        try await stateService.deleteAccount()
        await vaultTimeoutService.remove(userId: nil)
    }

    func getAccounts() async throws -> [ProfileSwitcherItem] {
        let accounts = try await stateService.getAccounts()
        return await accounts.asyncMap { account in
            await profileItem(from: account)
        }
    }

    func getActiveAccount() async throws -> ProfileSwitcherItem {
        let active = try await stateService.getActiveAccount()
        return await profileItem(from: active)
    }

    func getAccount(for userId: String) async throws -> Account {
        let accounts = try await stateService.getAccounts()
        guard let match = accounts.first(where: { account in
            account.profile.userId == userId
        }) else {
            throw StateServiceError.noAccounts
        }
        return match
    }

    func getFingerprintPhrase(userId _: String?) async throws -> String {
        let account = try await stateService.getActiveAccount()
        return try await clientPlatform.userFingerprint(fingerprintMaterial: account.profile.userId)
    }

    func lockVault(userId: String?) async {
        await vaultTimeoutService.lockVault(userId: userId)
    }

    func logout(userId: String?) async throws {
        await vaultTimeoutService.remove(userId: userId)
        try? await biometricsService.setBiometricUnlockKey(authKey: nil, for: userId)
        try await stateService.logoutAccount(userId: userId)
    }

    func passwordStrength(email: String, password: String) async -> UInt8 {
        await clientAuth.passwordStrength(password: password, email: email, additionalInputs: [])
    }

    func setActiveAccount(userId: String) async throws -> Account {
        try await stateService.setActiveAccount(userId: userId)
        await environmentService.loadURLsForActiveAccount()
        return try await stateService.getActiveAccount()
    }

    func unlockVault(password: String) async throws {
        let account = try await stateService.getActiveAccount()
        let encryptionKeys = try await stateService
            .getAccountEncryptionKeys(userId: account.profile.userId)
        try await unlockVault(
            for: account,
            using: .password(
                password: password,
                userKey: encryptionKeys.encryptedUserKey
            )
        )

        let hashedPassword = try await authService.hashPassword(password: password, purpose: .localAuthorization)
        try await stateService.setMasterPasswordHash(hashedPassword)
    }

    private func unlockVault(for account: Account, using method: InitUserCryptoMethod) async throws {
        let encryptionKeys = try await stateService
            .getAccountEncryptionKeys(userId: account.profile.userId)
        try await clientCrypto.initializeUserCrypto(
            req: InitUserCryptoRequest(
                kdfParams: account.kdf.sdkKdf,
                email: account.profile.email,
                privateKey: encryptionKeys.encryptedPrivateKey,
                method: method
            )
        )
        try await organizationService.initializeOrganizationCrypto()
        switch method {
        case let .password(password, _):
            let hashedPassword = try await authService.hashPassword(
                password: password,
                purpose: .localAuthorization
            )
            try await stateService.setMasterPasswordHash(hashedPassword)

            // Re-enable biometrics, if required.
            let biometricUnlockStatus = try? await biometricsService.getBiometricUnlockStatus()
            switch biometricUnlockStatus {
            case .available(_, true, false):
                try await biometricsService.configureBiometricIntegrity()
                try await biometricsService.setBiometricUnlockKey(
                    authKey: clientCrypto.getUserEncryptionKey(),
                    for: account.profile.userId
                )
            default:
                break
            }
        case .decryptedKey:
            break
        case .pin:
            break
        }

        await vaultTimeoutService.unlockVault(userId: account.profile.userId)
    }

    func unlockVaultWithBiometrics() async throws {
        let account = try await stateService.getActiveAccount()
        let decryptedUserKey = try await biometricsService.getUserAuthKey(for: account.profile.userId)
        try await unlockVault(for: account, using: .decryptedKey(decryptedUserKey: decryptedUserKey))
    }

    /// A function to convert an `Account` to a `ProfileSwitcherItem`
    ///
    ///   - Parameter account: The account to convert.
    ///   - Returns: The `ProfileSwitcherItem` representing the account.
    ///
    func profileItem(from account: Account) async -> ProfileSwitcherItem {
        var profile = ProfileSwitcherItem(
            email: account.profile.email,
            userId: account.profile.userId,
            userInitials: account.initials()
                ?? ".."
        )
        do {
            let isUnlocked = try !vaultTimeoutService.isLocked(userId: account.profile.userId)
            profile.isUnlocked = isUnlocked
            return profile
        } catch {
            profile.isUnlocked = false
            let userId = profile.userId
            await vaultTimeoutService.lockVault(userId: userId)
            return profile
        }
    }
}
