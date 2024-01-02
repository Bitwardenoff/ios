import XCTest

@testable import BitwardenShared

class EnvironmentServiceTests: XCTestCase {
    // MARK: Properties

    var stateService: MockStateService!
    var subject: EnvironmentService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        stateService = MockStateService()

        subject = DefaultEnvironmentService(stateService: stateService)
    }

    override func tearDown() {
        super.tearDown()

        stateService = nil
        subject = nil
    }

    // MARK: Tests

    /// The default US URLs are returned if the URLs haven't been loaded.
    func test_defaultUrls() {
        XCTAssertEqual(subject.apiURL, URL(string: "https://vault.bitwarden.com/api"))
        XCTAssertEqual(subject.eventsURL, URL(string: "https://vault.bitwarden.com/events"))
        XCTAssertEqual(subject.identityURL, URL(string: "https://vault.bitwarden.com/identity"))
        XCTAssertEqual(subject.webVaultURL, URL(string: "https://vault.bitwarden.com"))
    }

    /// `loadURLsForActiveAccount()` loads the URLs for the active account.
    func test_loadURLsForActiveAccount() async {
        let urls = EnvironmentUrlData(base: .example)
        let account = Account.fixture(settings: .fixture(environmentUrls: urls))
        stateService.activeAccount = account
        stateService.environmentUrls = [account.profile.userId: urls]

        await subject.loadURLsForActiveAccount()

        XCTAssertEqual(subject.apiURL, URL(string: "https://example.com/api"))
        XCTAssertEqual(subject.eventsURL, URL(string: "https://example.com/events"))
        XCTAssertEqual(subject.identityURL, URL(string: "https://example.com/identity"))
        XCTAssertEqual(subject.webVaultURL, URL(string: "https://example.com"))
    }

    /// `loadURLsForActiveAccount()` loads the default URLs if there's no active account.
    func test_loadURLsForActiveAccount_noAccount() async {
        await subject.loadURLsForActiveAccount()

        XCTAssertEqual(subject.apiURL, URL(string: "https://vault.bitwarden.com/api"))
        XCTAssertEqual(subject.eventsURL, URL(string: "https://vault.bitwarden.com/events"))
        XCTAssertEqual(subject.identityURL, URL(string: "https://vault.bitwarden.com/identity"))
        XCTAssertEqual(subject.webVaultURL, URL(string: "https://vault.bitwarden.com"))
    }

    /// `setPreAuthURLs(urls:)` sets the pre-auth URLs.
    func test_setPreAuthURLs() async {
        let urls = EnvironmentUrlData(base: .example)

        await subject.setPreAuthURLs(urls: urls)

        XCTAssertEqual(subject.apiURL, URL(string: "https://example.com/api"))
        XCTAssertEqual(subject.eventsURL, URL(string: "https://example.com/events"))
        XCTAssertEqual(subject.identityURL, URL(string: "https://example.com/identity"))
        XCTAssertEqual(subject.webVaultURL, URL(string: "https://example.com"))
        XCTAssertEqual(stateService.preAuthEnvironmentUrls, urls)
    }
}
