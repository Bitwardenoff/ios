import BitwardenSdk
import Combine

@testable import BitwardenShared

class MockVaultRepository: VaultRepository {
    var addCipherCiphers = [BitwardenSdk.CipherView]()
    var addCipherResult: Result<Void, Error> = .success(())
    var ciphersSubject = CurrentValueSubject<[CipherListView], Error>([])
    var cipherDetailsSubject = CurrentValueSubject<BitwardenSdk.CipherView, Never>(.fixture())
    var deletedCipher = [String]()
    var deleteCipherResult: Result<Void, Error> = .success(())
    var doesActiveAccountHavePremiumCalled = false
    var fetchCipherId: String?
    var fetchCipherResult: Result<CipherView?, Error> = .success(nil)
    var fetchCipherOwnershipOptionsIncludePersonal: Bool? // swiftlint:disable:this identifier_name
    var fetchCipherOwnershipOptions = [CipherOwner]()
    var fetchCollectionsIncludeReadOnly: Bool?
    var fetchCollectionsResult: Result<[CollectionView], Error> = .success([])
    var fetchFoldersResult: Result<[FolderView], Error> = .success([])
    var fetchSyncCalled = false
    var getActiveAccountIdResult: Result<String, StateServiceError> = .failure(.noActiveAccount)
    var hasPremiumResult: Result<Bool, Error> = .success(true)
    var organizationsSubject = CurrentValueSubject<[Organization], Error>([])
    var removeAccountIds = [String?]()
    var shareCipherResult: Result<Void, Error> = .success(())
    var sharedCiphers = [CipherView]()
    var softDeletedCipher = [CipherView]()
    var softDeleteCipherResult: Result<Void, Error> = .success(())
    var updateCipherCiphers = [BitwardenSdk.CipherView]()
    var updateCipherResult: Result<Void, Error> = .success(())
    var updateCipherCollectionsCiphers = [CipherView]()
    var updateCipherCollectionsResult: Result<Void, Error> = .success(())
    var validatePasswordPasswords = [String]()
    var validatePasswordResult: Result<Bool, Error> = .success(true)
    var vaultListSubject = CurrentValueSubject<[VaultListSection], Never>([])
    var vaultListGroupSubject = CurrentValueSubject<[VaultListItem], Never>([])
    var vaultListFilter: VaultFilterType?

    func addCipher(_ cipher: BitwardenSdk.CipherView) async throws {
        addCipherCiphers.append(cipher)
        try addCipherResult.get()
    }

    func cipherPublisher() async throws -> AsyncThrowingPublisher<AnyPublisher<[CipherListView], Error>> {
        ciphersSubject.eraseToAnyPublisher().values
    }

    func cipherDetailsPublisher(id _: String) -> AsyncPublisher<AnyPublisher<BitwardenSdk.CipherView, Never>> {
        cipherDetailsSubject.eraseToAnyPublisher().values
    }

    func deleteCipher(_ id: String) async throws {
        deletedCipher.append(id)
        try deleteCipherResult.get()
    }

    func doesActiveAccountHavePremium() async throws -> Bool {
        doesActiveAccountHavePremiumCalled = true
        return try hasPremiumResult.get()
    }

    func fetchCipher(withId id: String) async throws -> CipherView? {
        fetchCipherId = id
        return try fetchCipherResult.get()
    }

    func fetchCipherOwnershipOptions(includePersonal: Bool) async throws -> [CipherOwner] {
        fetchCipherOwnershipOptionsIncludePersonal = includePersonal
        return fetchCipherOwnershipOptions
    }

    func fetchCollections(includeReadOnly: Bool) async throws -> [CollectionView] {
        fetchCollectionsIncludeReadOnly = includeReadOnly
        return try fetchCollectionsResult.get()
    }

    func fetchFolders() async throws -> [FolderView] {
        try fetchFoldersResult.get()
    }

    func fetchSync(isManualRefresh _: Bool) async throws {
        fetchSyncCalled = true
    }

    func organizationsPublisher() async throws -> AsyncThrowingPublisher<AnyPublisher<[Organization], Error>> {
        organizationsSubject.eraseToAnyPublisher().values
    }

    func remove(userId: String?) async {
        removeAccountIds.append(userId)
    }

    func shareCipher(_ cipher: CipherView) async throws {
        sharedCiphers.append(cipher)
        try shareCipherResult.get()
    }

    func softDeleteCipher(_ cipher: CipherView) async throws {
        softDeletedCipher.append(cipher)
        try softDeleteCipherResult.get()
    }

    func updateCipher(_ cipher: BitwardenSdk.CipherView) async throws {
        updateCipherCiphers.append(cipher)
        try updateCipherResult.get()
    }

    func updateCipherCollections(_ cipher: CipherView) async throws {
        updateCipherCollectionsCiphers.append(cipher)
        try updateCipherCollectionsResult.get()
    }

    func validatePassword(_ password: String) async throws -> Bool {
        validatePasswordPasswords.append(password)
        return try validatePasswordResult.get()
    }

    func vaultListPublisher(
        filter: VaultFilterType
    ) -> AsyncPublisher<AnyPublisher<[BitwardenShared.VaultListSection], Never>> {
        vaultListFilter = filter
        return vaultListSubject.eraseToAnyPublisher().values
    }

    func vaultListPublisher(
        group _: BitwardenShared.VaultListGroup
    ) -> AsyncPublisher<AnyPublisher<[VaultListItem], Never>> {
        vaultListGroupSubject.eraseToAnyPublisher().values
    }
}
