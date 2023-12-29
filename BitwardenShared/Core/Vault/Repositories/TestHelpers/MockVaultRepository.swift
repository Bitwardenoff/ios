import BitwardenSdk
import Combine

@testable import BitwardenShared

class MockVaultRepository: VaultRepository {
    var addCipherCiphers = [BitwardenSdk.CipherView]()
    var addCipherResult: Result<Void, Error> = .success(())
    var cipherDetailsSubject = CurrentValueSubject<BitwardenSdk.CipherView, Never>(.fixture())
    var fetchCipherOwnershipOptions = [CipherOwner]()
    var fetchCollectionsIncludeReadOnly: Bool?
    var fetchCollectionsResult: Result<[CollectionView], Error> = .success([])
    var fetchSyncCalled = false
    var getActiveAccountIdResult: Result<String, StateServiceError> = .failure(.noActiveAccount)
    var removeAccountIds = [String?]()
    var updateCipherCiphers = [BitwardenSdk.CipherView]()
    var updateCipherResult: Result<Void, Error> = .success(())
    var organizationsSubject = CurrentValueSubject<[Organization], Never>([])
    var validatePasswordPasswords = [String]()
    var validatePasswordResult: Result<Bool, Error> = .success(true)
    var vaultListSubject = CurrentValueSubject<[VaultListSection], Never>([])
    var vaultListGroupSubject = CurrentValueSubject<[VaultListItem], Never>([])
    var vaultListFilter: VaultFilterType?

    func fetchSync(isManualRefresh _: Bool) async throws {
        fetchSyncCalled = true
    }

    func addCipher(_ cipher: BitwardenSdk.CipherView) async throws {
        addCipherCiphers.append(cipher)
        try addCipherResult.get()
    }

    func cipherDetailsPublisher(id _: String) -> AsyncPublisher<AnyPublisher<BitwardenSdk.CipherView, Never>> {
        cipherDetailsSubject.eraseToAnyPublisher().values
    }

    func fetchCipherOwnershipOptions() async throws -> [CipherOwner] {
        fetchCipherOwnershipOptions
    }

    func fetchCollections(includeReadOnly: Bool) async throws -> [CollectionView] {
        fetchCollectionsIncludeReadOnly = includeReadOnly
        return try fetchCollectionsResult.get()
    }

    func remove(userId: String?) async {
        removeAccountIds.append(userId)
    }

    func updateCipher(_ cipher: BitwardenSdk.CipherView) async throws {
        updateCipherCiphers.append(cipher)
        try updateCipherResult.get()
    }

    func organizationsPublisher() -> AsyncPublisher<AnyPublisher<[Organization], Never>> {
        organizationsSubject.eraseToAnyPublisher().values
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
