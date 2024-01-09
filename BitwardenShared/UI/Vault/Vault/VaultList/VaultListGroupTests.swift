import XCTest

@testable import BitwardenShared

// MARK: - VaultListGroupTests

class VaultListGroupTests: BitwardenTestCase {
    // MARK: Tests

    /// `name` returns the display name of the group.
    func test_name() {
        XCTAssertEqual(VaultListGroup.card.name, "Card")
        XCTAssertEqual(VaultListGroup.collection(id: "", name: "Collection 🗂️").name, "Collection 🗂️")
        XCTAssertEqual(VaultListGroup.folder(id: "", name: "Folder 📁").name, "Folder 📁")
        XCTAssertEqual(VaultListGroup.identity.name, "Identity")
        XCTAssertEqual(VaultListGroup.login.name, "Login")
        XCTAssertEqual(VaultListGroup.secureNote.name, "Secure note")
        XCTAssertEqual(VaultListGroup.totp.name, Localizations.verificationCodes)
        XCTAssertEqual(VaultListGroup.trash.name, "Trash")
    }

    /// `navigationTitle` returns the navigation title of the group.
    func test_navigationTitle() {
        XCTAssertEqual(VaultListGroup.card.navigationTitle, Localizations.cards)
        XCTAssertEqual(VaultListGroup.collection(id: "", name: "Collection 🗂️").navigationTitle, "Collection 🗂️")
        XCTAssertEqual(VaultListGroup.folder(id: "", name: "Folder 📁").navigationTitle, "Folder 📁")
        XCTAssertEqual(VaultListGroup.identity.navigationTitle, Localizations.identities)
        XCTAssertEqual(VaultListGroup.login.navigationTitle, Localizations.logins)
        XCTAssertEqual(VaultListGroup.secureNote.navigationTitle, Localizations.secureNotes)
        XCTAssertEqual(VaultListGroup.totp.navigationTitle, Localizations.verificationCodes)
        XCTAssertEqual(VaultListGroup.trash.navigationTitle, Localizations.trash)
    }
}
