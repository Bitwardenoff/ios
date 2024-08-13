import SnapshotTesting
import XCTest

@testable import BitwardenShared

class ExtensionActivationViewTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<ExtensionActivationState, ExtensionActivationAction, Void>!
    var subject: ExtensionActivationView!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        processor = MockProcessor(state: ExtensionActivationState(extensionType: .autofillExtension))
        let store = Store(processor: processor)

        subject = ExtensionActivationView(store: store)
    }

    override func tearDown() {
        super.tearDown()

        processor = nil
        subject = nil
    }

    // MARK: Tests

    /// Tapping the cancel button dispatches the `.cancelTapped` action.
    @MainActor
    func test_cancelButton_tap() throws {
        let button = try subject.inspect().find(button: Localizations.cancel)
        try button.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .cancelTapped)
    }

    // MARK: Snapshots

    /// The autofill extension activation view renders correctly.
    func test_snapshot_extensionActivationView_autofillExtension() {
        assertSnapshots(
            of: subject.navStackWrapped,
            as: [.defaultPortrait, .defaultPortraitDark, .defaultPortraitAX5]
        )
    }

    /// The app extension activation view renders correctly.
    @MainActor
    func test_snapshot_extensionActivationView_appExtension() {
        processor.state.extensionType = .appExtension
        assertSnapshots(
            of: subject.navStackWrapped,
            as: [.defaultPortrait, .defaultPortraitDark, .defaultPortraitAX5]
        )
    }
}
