import XCTest

@testable import BitwardenShared

class EventServiceTests: XCTestCase {
    // MARK: Properties

    var cipherService: MockCipherService!
    var errorReporter: MockErrorReporter!
    var organizationService: MockOrganizationService!
    var stateService: MockStateService!
    var subject: EventService!
    var timeProvider: MockTimeProvider!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        cipherService = MockCipherService()
        errorReporter = MockErrorReporter()
        organizationService = MockOrganizationService()
        stateService = MockStateService()
        timeProvider = MockTimeProvider(.mockTime(Date(year: 2024, month: 6, day: 28)))
        subject = DefaultEventService(
            cipherService: cipherService,
            errorReporter: errorReporter,
            organizationService: organizationService,
            stateService: stateService,
            timeProvider: timeProvider
        )
    }

    override func tearDown() {
        super.tearDown()

        cipherService = nil
        errorReporter = nil
        organizationService = nil
        stateService = nil
        subject = nil
        timeProvider = nil
    }

    // MARK: Tests

    /// `collect(eventType:cipherId:)` saves events to the state service
    /// if the user is authenticated, is part of organizations, and those organizations use events.
    func test_collect() async throws {
        stateService.accounts = [.fixture(profile: .fixture(userId: "1"))]
        try await stateService.setActiveAccount(userId: "1")
        organizationService.fetchAllOrganizationsResult = .success([.fixture(useEvents: true)])
        stateService.events["1"] = [
            EventData(type: .cipherClientViewed, cipherId: nil, date: timeProvider.presentTime.advanced(by: -5)),
        ]

        await subject.collect(eventType: .userLoggedIn)

        let actual = stateService.events["1"]
        XCTAssertEqual(
            actual,
            [
                EventData(type: .cipherClientViewed, cipherId: nil, date: timeProvider.presentTime.advanced(by: -5)),
                EventData(type: .userLoggedIn, cipherId: nil, date: timeProvider.presentTime),
            ]
        )
    }

    /// `collect(eventType:cipherId:)` saves events to the state service
    /// if the cipher ID belongs to one of the organizations the user is a member of
    /// and the organization uses events.
    func test_collect_cipher() async throws {
        stateService.accounts = [.fixture(profile: .fixture(userId: "1"))]
        try await stateService.setActiveAccount(userId: "1")
        organizationService.fetchAllOrganizationsResult = .success([.fixture(id: "One", useEvents: true)])
        cipherService.fetchCipherResult = .success(.fixture(organizationId: "One"))

        await subject.collect(eventType: .userLoggedIn, cipherId: "1")

        let actual = stateService.events["1"]
        XCTAssertEqual(
            actual,
            [EventData(type: .userLoggedIn, cipherId: "1", date: timeProvider.presentTime)]
        )
    }

    /// `collect(eventType:cipherId:)` does not collect events
    /// if the cipher ID refers to a cipher the user doesn't have
    func test_collect_cipher_noCipher() async throws {
        stateService.accounts = [.fixture(profile: .fixture(userId: "1"))]
        try await stateService.setActiveAccount(userId: "1")
        organizationService.fetchAllOrganizationsResult = .success([.fixture(useEvents: true)])

        await subject.collect(eventType: .userLoggedIn, cipherId: "1")
        XCTAssertEqual(stateService.events, [:])
    }

    /// `collect(eventType:cipherId:)` does not collect events
    /// if the cipher ID does not belong to one of the event-using organizations the user is a member of
    func test_collect_cipher_noOrganizations() async throws {
        stateService.accounts = [.fixture(profile: .fixture(userId: "1"))]
        try await stateService.setActiveAccount(userId: "1")
        organizationService.fetchAllOrganizationsResult = .success([.fixture(id: "One", useEvents: true)])
        cipherService.fetchCipherResult = .success(.fixture(organizationId: "Two"))

        await subject.collect(eventType: .userLoggedIn, cipherId: "1")
        XCTAssertEqual(stateService.events, [:])
    }

    /// `collect(eventType:cipherId:)` does not collect events
    /// if an error is thrown
    func test_collect_error() async throws {
        stateService.accounts = [.fixture(profile: .fixture(userId: "1"))]
        try await stateService.setActiveAccount(userId: "1")
        organizationService.fetchAllOrganizationsResult = .failure(BitwardenTestError.example)

        await subject.collect(eventType: .userLoggedIn, cipherId: "1")
        XCTAssertEqual(errorReporter.errors as? [BitwardenTestError], [.example])
    }

    /// `collect(eventType:cipherId:)` does not collect events
    /// if the user is not in any organizations.
    func test_collect_noOrganizations() async throws {
        stateService.accounts = [.fixture(profile: .fixture(userId: "1"))]
        try await stateService.setActiveAccount(userId: "1")

        await subject.collect(eventType: .userLoggedIn)
        XCTAssertEqual(stateService.events, [:])
    }

    /// `collect(eventType:cipherId:)` does not collect events
    /// if the user is not part of any organizations that use events.
    func test_collect_organizationDoesntUseEvents() async throws {
        stateService.accounts = [.fixture(profile: .fixture(userId: "1"))]
        try await stateService.setActiveAccount(userId: "1")
        organizationService.fetchAllOrganizationsResult = .success([.fixture(useEvents: false)])

        await subject.collect(eventType: .userLoggedIn)
        XCTAssertEqual(stateService.events, [:])
    }

    /// `collect(eventType:cipherId:)` does not collect events
    /// if the user is not authenticated.
    func test_collect_unauthenticated() async throws {
        await subject.collect(eventType: .userLoggedIn)
        XCTAssertEqual(stateService.events, [:])
    }
}
