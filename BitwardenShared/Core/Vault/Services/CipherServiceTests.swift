import BitwardenSdk
import XCTest

@testable import BitwardenShared

class CipherServiceTests: XCTestCase {
    // MARK: Properties

    var cipherDataStore: MockCipherDataStore!
    var cipherAPIService: CipherAPIService!
    var client: MockHTTPClient!
    var stateService: MockStateService!
    var subject: CipherService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        client = MockHTTPClient()
        cipherAPIService = APIService(client: client)
        cipherDataStore = MockCipherDataStore()
        stateService = MockStateService()

        subject = DefaultCipherService(
            cipherAPIService: cipherAPIService,
            cipherDataStore: cipherDataStore,
            stateService: stateService
        )
    }

    override func tearDown() {
        super.tearDown()

        cipherDataStore = nil
        subject = nil
    }

    // MARK: Tests

    /// `deleteCipherWithServer(id:)` deletes the cipher item from remote server and persisted cipher in the data store.
    func test_deleteCipher() async throws {
        stateService.accounts = [.fixtureAccountLogin()]
        stateService.activeAccount = .fixtureAccountLogin()
        client.result = .httpSuccess(testData: APITestData(data: Data()))
        try await subject.deleteCipherWithServer(id: "TestId")
        XCTAssertEqual(cipherDataStore.deleteCipherId, "TestId")
        XCTAssertEqual(cipherDataStore.deleteCipherUserId, "13512467-9cfe-43b0-969f-07534084764b")
    }

    /// `replaceCiphers(_:userId:)` replaces the persisted ciphers in the data store.
    func test_replaceCiphers() async throws {
        let ciphers: [CipherDetailsResponseModel] = [
            CipherDetailsResponseModel.fixture(id: "1", name: "Cipher 1"),
            CipherDetailsResponseModel.fixture(id: "2", name: "Cipher 2"),
        ]

        try await subject.replaceCiphers(ciphers, userId: "1")

        XCTAssertEqual(cipherDataStore.replaceCiphersValue, ciphers.map(Cipher.init))
        XCTAssertEqual(cipherDataStore.replaceCiphersUserId, "1")
    }
}
