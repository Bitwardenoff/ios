@testable import BitwardenShared

class MockStateService: StateService {
    var accountEncryptionKeys = [String: AccountEncryptionKeys]()
    var accountsAdded = [Account]()
    var accountsLoggedOut = [String]()
    var activeAccount: Account?

    func addAccount(_ account: BitwardenShared.Account) async {
        accountsAdded.append(account)
    }

    func getAccountEncryptionKeys(_ userId: String) async -> AccountEncryptionKeys? {
        accountEncryptionKeys[userId]
    }

    func getActiveAccount() async -> Account? {
        activeAccount
    }

    func logoutAccount(_ userId: String) async {
        accountsLoggedOut.append(userId)
    }

    func setAccountEncryptionKeys(_ encryptionKeys: AccountEncryptionKeys, userId: String) async {
        accountEncryptionKeys[userId] = encryptionKeys
    }
}
