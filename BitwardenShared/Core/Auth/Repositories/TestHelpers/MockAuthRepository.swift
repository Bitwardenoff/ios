@testable import BitwardenShared

class MockAuthRepository: AuthRepository {
    var accountsResult: Result<[ProfileSwitcherItem], Error> = .failure(StateServiceError.noAccounts)
    var activeAccountResult: Result<ProfileSwitcherItem, Error> = .failure(StateServiceError.noActiveAccount)
    var accountForItemResult: Result<Account, Error> = .failure(StateServiceError.noAccounts)
    var deleteAccountCalled = false
    var logoutCalled = false
    var passwordStrengthEmail: String?
    var passwordStrengthPassword: String?
    var passwordStrengthResult: UInt8 = 0
    var setActiveAccountResult: Result<Account, Error> = .failure(StateServiceError.noAccounts)
    var unlockVaultPassword: String?
    var unlockVaultResult: Result<Void, Error> = .success(())

    func deleteAccount(passwordText: String) async throws {
        deleteAccountCalled = true
    }

    func getAccounts() async throws -> [ProfileSwitcherItem] {
        try accountsResult.get()
    }

    func getActiveAccount() async throws -> ProfileSwitcherItem {
        try activeAccountResult.get()
    }

    func getAccount(for userId: String) async throws -> BitwardenShared.Account {
        try accountForItemResult.get()
    }

    func passwordStrength(email: String, password: String) async -> UInt8 {
        passwordStrengthEmail = email
        passwordStrengthPassword = password
        return passwordStrengthResult
    }

    func logout() async throws {
        logoutCalled = true
    }

    func setActiveAccount(userId: String) async throws -> Account {
        try setActiveAccountResult.get()
    }

    func unlockVault(password: String) async throws {
        unlockVaultPassword = password
        try unlockVaultResult.get()
    }
}
