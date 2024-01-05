import BitwardenSdk

// MARK: - CipherService

/// A protocol for a `CipherService` which manages syncing and updates to the user's ciphers.
///
protocol CipherService {
    /// Replaces the persisted list of ciphers for the user.
    ///
    /// - Parameters:
    ///   - ciphers: The updated list of ciphers for the user.
    ///   - userId: The user ID associated with the ciphers.
    ///
    func replaceCiphers(_ ciphers: [CipherDetailsResponseModel], userId: String) async throws

    /// Shares a cipher with an organization and updates the locally stored data.
    ///
    /// - Parameter cipher: The cipher to share.
    ///
    func shareWithServer(_ cipher: Cipher) async throws
}

// MARK: - DefaultCipherService

class DefaultCipherService: CipherService {
    // MARK: Properties

    /// The service used to make cipher related API requests.
    let cipherAPIService: CipherAPIService

    /// The data store for managing the persisted ciphers for the user.
    let cipherDataStore: CipherDataStore

    /// The service used by the application to manage account state.
    let stateService: StateService

    // MARK: Initialization

    /// Initialize a `DefaultCipherService`.
    ///
    /// - Parameters:
    ///   - cipherAPIService: The service used to make cipher related API requests.
    ///   - cipherDataStore: The data store for managing the persisted ciphers for the user.
    ///   - stateService: The service used by the application to manage account state.
    ///
    init(
        cipherAPIService: CipherAPIService,
        cipherDataStore: CipherDataStore,
        stateService: StateService
    ) {
        self.cipherAPIService = cipherAPIService
        self.cipherDataStore = cipherDataStore
        self.stateService = stateService
    }
}

extension DefaultCipherService {
    func replaceCiphers(_ ciphers: [CipherDetailsResponseModel], userId: String) async throws {
        try await cipherDataStore.replaceCiphers(ciphers.map(Cipher.init), userId: userId)
    }

    func shareWithServer(_ cipher: Cipher) async throws {
        let userID = try await stateService.getActiveAccountId()
        var response = try await cipherAPIService.shareCipher(cipher)
        response.collectionIds = cipher.collectionIds
        try await cipherDataStore.upsertCipher(Cipher(responseModel: response), userId: userID)
    }
}
