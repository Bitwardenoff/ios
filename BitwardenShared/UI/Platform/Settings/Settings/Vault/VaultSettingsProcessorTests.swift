import XCTest

@testable import BitwardenShared

class VaultSettingsProcessorTests: BitwardenTestCase {
    // MARK: Properties

    var coordinator: MockCoordinator<SettingsRoute>!
    var subject: VaultSettingsProcessor!

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()

        coordinator = MockCoordinator<SettingsRoute>()
        subject = VaultSettingsProcessor(coordinator: coordinator.asAnyCoordinator(), state: VaultSettingsState())
    }

    override func tearDown() {
        super.tearDown()

        coordinator = nil
        subject = nil
    }

    // MARK: Tests

    /// `receive(_:)` with `.clearImportItemsUrl` clears the URL in the state.
    func test_receive_clearImportItemsUrl() {
        subject.state.importItemsUrl = .example
        subject.receive(.clearImportItemsUrl)

        XCTAssertNil(subject.state.importItemsUrl)
    }

    /// Receiving `.exportVaultTapped` navigates to the export vault screen.
    func test_receive_exportVaultTapped() {
        subject.receive(.exportVaultTapped)

        XCTAssertEqual(coordinator.routes.last, .exportVault)
    }

    /// Receiving `.foldersTapped` navigates to the folders screen.
    func test_receive_foldersTapped() {
        subject.receive(.foldersTapped)

        XCTAssertEqual(coordinator.routes.last, .folders)
    }

    /// `receive(_:)` with `.importItemsTapped` set the URL to open in the state.
    func test_receive_importItemsTapped() {
        subject.receive(.importItemsTapped)

        XCTAssertEqual(subject.state.importItemsUrl, ExternalLinksConstants.importItems)
    }
}
