import BitwardenSdk
@testable import BitwardenShared
import Combine

class MockCipherService: CipherService {
    var replaceCiphersCiphers: [CipherDetailsResponseModel]?
    var replaceCiphersUserId: String?

    var cipherPublisherUserId: String?
    var cipherSubject = CurrentValueSubject<[Cipher], Error>([])

    var deleteCipherId: String?
    var deleteWithServerResult: Result<Void, Error> = .success(())

    var shareWithServerCiphers = [Cipher]()
    var shareWithServerResult: Result<Void, Error> = .success(())

    var softDeleteCipherId: String?
    var softDeleteCipher: Cipher?
    var softDeleteWithServerResult: Result<Void, Error> = .success(())

    func cipherPublisher(userId: String) -> AnyPublisher<[BitwardenSdk.Cipher], Error> {
        cipherPublisherUserId = userId
        return cipherSubject.eraseToAnyPublisher()
    }

    func deleteCipherWithServer(id: String) async throws {
        deleteCipherId = id
        try deleteWithServerResult.get()
    }

    func replaceCiphers(_ ciphers: [CipherDetailsResponseModel], userId: String) async throws {
        replaceCiphersCiphers = ciphers
        replaceCiphersUserId = userId
    }

    func shareWithServer(_ cipher: Cipher) async throws {
        shareWithServerCiphers.append(cipher)
        try shareWithServerResult.get()
    }

    func softDeleteCipherWithServer(id: String, _ cipher: Cipher) async throws {
        softDeleteCipherId = id
        softDeleteCipher = cipher
        try softDeleteWithServerResult.get()
    }
}
