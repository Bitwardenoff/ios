import Combine
import Foundation

@testable import BitwardenShared

class MockStateService: StateService {
    var accountEncryptionKeys = [String: AccountEncryptionKeys]()
    var accountTokens: Account.AccountTokens?
    var accountsAdded = [Account]()
    var accountsLoggedOut = [String]()
    var activeAccount: Account?
    var accounts: [Account]?
    var environmentUrls = [String: EnvironmentUrlData]()
    var lastSyncTimeByUserId = [String: Date]()
    var lastSyncTimeSubject = CurrentValueSubject<Date?, Never>(nil)
    var masterPasswordHashes = [String: String]()
    var passwordGenerationOptions = [String: PasswordGenerationOptions]()
    var preAuthEnvironmentUrls: EnvironmentUrlData?
    var usernameGenerationOptions = [String: UsernameGenerationOptions]()

    lazy var activeIdSubject = CurrentValueSubject<String?, Never>(self.activeAccount?.profile.userId)

    func addAccount(_ account: BitwardenShared.Account) async {
        accountsAdded.append(account)
        activeAccount = account
    }

    func deleteAccount() async throws {
        accounts?.removeAll(where: { account in
            account == activeAccount
        })
    }

    func getAccountEncryptionKeys(userId: String?) async throws -> AccountEncryptionKeys {
        let userId = try userId ?? getActiveAccount().profile.userId
        guard let encryptionKeys = accountEncryptionKeys[userId]
        else {
            throw StateServiceError.noActiveAccount
        }
        return encryptionKeys
    }

    func getAccounts() async throws -> [BitwardenShared.Account] {
        guard let accounts else { throw StateServiceError.noAccounts }
        return accounts
    }

    func getActiveAccount() throws -> Account {
        guard let activeAccount else { throw StateServiceError.noActiveAccount }
        return activeAccount
    }

    func getAccountIdOrActiveId(userId: String?) async throws -> String {
        guard let knownAccounts = accounts else {
            throw StateServiceError.noAccounts
        }
        if let userId {
            guard knownAccounts.contains(where: { $0.profile.userId == userId }) else {
                throw StateServiceError.noAccounts
            }
            return userId
        } else {
            return try await getActiveAccountId()
        }
    }

    func getActiveAccountId() async throws -> String {
        try getActiveAccount().profile.userId
    }

    func getEnvironmentUrls(userId: String?) async throws -> EnvironmentUrlData? {
        let userId = try userId ?? getActiveAccount().profile.userId
        return environmentUrls[userId]
    }

    func getMasterPasswordHash(userId: String?) async throws -> String? {
        let userId = try userId ?? getActiveAccount().profile.userId
        return masterPasswordHashes[userId]
    }

    func getPasswordGenerationOptions(userId: String?) async throws -> PasswordGenerationOptions? {
        let userId = try userId ?? getActiveAccount().profile.userId
        return passwordGenerationOptions[userId]
    }

    func getPreAuthEnvironmentUrls() async -> EnvironmentUrlData? {
        preAuthEnvironmentUrls
    }

    func getUsernameGenerationOptions(userId: String?) async throws -> UsernameGenerationOptions? {
        let userId = try userId ?? getActiveAccount().profile.userId
        return usernameGenerationOptions[userId]
    }

    func logoutAccount(userId: String?) async throws {
        let userId = try userId ?? getActiveAccount().profile.userId
        accountsLoggedOut.append(userId)
    }

    func setAccountEncryptionKeys(_ encryptionKeys: AccountEncryptionKeys, userId: String?) async throws {
        let userId = try userId ?? getActiveAccount().profile.userId
        accountEncryptionKeys[userId] = encryptionKeys
    }

    func setActiveAccount(userId: String) async throws {
        guard let accounts,
              let match = accounts.first(where: { account in
                  account.profile.userId == userId
              }) else { throw StateServiceError.noAccounts }
        activeAccount = match
    }

    func setEnvironmentUrls(_ environmentUrls: EnvironmentUrlData, userId: String?) async throws {
        let userId = try userId ?? getActiveAccount().profile.userId
        self.environmentUrls[userId] = environmentUrls
    }

    func setLastSyncTime(_ date: Date?, userId: String?) async throws {
        let userId = try userId ?? getActiveAccount().profile.userId
        lastSyncTimeByUserId[userId] = date
    }

    func setMasterPasswordHash(_ hash: String?, userId: String?) async throws {
        let userId = try userId ?? getActiveAccount().profile.userId
        masterPasswordHashes[userId] = hash
    }

    func setPasswordGenerationOptions(_ options: PasswordGenerationOptions?, userId: String?) async throws {
        let userId = try userId ?? getActiveAccount().profile.userId
        passwordGenerationOptions[userId] = options
    }

    func setPreAuthEnvironmentUrls(_ urls: BitwardenShared.EnvironmentUrlData) async {
        preAuthEnvironmentUrls = urls
    }

    func setTokens(accessToken: String, refreshToken: String, userId: String?) async throws {
        accountTokens = Account.AccountTokens(accessToken: accessToken, refreshToken: refreshToken)
    }

    func setUsernameGenerationOptions(_ options: UsernameGenerationOptions?, userId: String?) async throws {
        let userId = try userId ?? getActiveAccount().profile.userId
        usernameGenerationOptions[userId] = options
    }

    func activeAccountIdPublisher() async -> AsyncPublisher<AnyPublisher<String?, Never>> {
        activeIdSubject
            .eraseToAnyPublisher()
            .values
    }

    func lastSyncTimePublisher() async throws -> AnyPublisher<Date?, Never> {
        lastSyncTimeSubject.eraseToAnyPublisher()
    }
}
