import UniformTypeIdentifiers
import XCTest

@testable import BitwardenShared

// MARK: - ShareExtensionHelperTests

class ShareExtensionHelperTests: BitwardenTestCase {
    // MARK: Properties

    var subject: ShareExtensionHelper!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        subject = ShareExtensionHelper()
    }

    override func tearDown() {
        super.tearDown()
        subject = nil
    }

    // MARK: Tests

    /// `processInputItems(_:)` processes the input items for the extension setup and returns a
    /// `.text` type.
    func test_processInputItems_text() async {
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [
            NSItemProvider(
                item: "text value" as NSString,
                typeIdentifier: UTType.plainText.identifier
            ),
        ]

        let content = await subject.processInputItems([extensionItem])

        XCTAssertEqual(content, .text("text value"))
    }

    /// `processInputItems(_:)` processes the input items for the extension setup and returns a
    /// `.file` type.
    func test_processInputItems_file() async throws {
        let data = Data("example".utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("example.txt")

        // Write to a temporary file
        try data.write(to: url)

        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [
            NSItemProvider(
                item: url as NSURL,
                typeIdentifier: UTType.data.identifier
            ),
        ]

        let content = await subject.processInputItems([extensionItem])

        XCTAssertEqual(content, .file(fileName: "example.txt", fileData: data))

        // Clean up the temporary file
        try FileManager.default.removeItem(at: url)
    }

    /// `processInputItems(_:)` processes the input items for content but does not return anything.
    func test_processInputItems_notSupportedType() async {
        let extensionItem = NSExtensionItem()
        extensionItem.attachments = [
            NSItemProvider(
                item: URL.example as NSURL,
                typeIdentifier: UTType.url.identifier
            ),
        ]

        let content = await subject.processInputItems([extensionItem])

        XCTAssertNil(content)
    }
}
