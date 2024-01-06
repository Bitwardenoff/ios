import XCTest

@testable import BitwardenShared

// MARK: - RootViewControllerTests

@MainActor
class RootViewControllerTests: BitwardenTestCase {
    // MARK: Properties

    var subject: RootViewController!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        subject = RootViewController()
        setKeyWindowRoot(viewController: subject)
    }

    override func tearDown() {
        super.tearDown()
        subject = nil
    }

    // MARK: Tests

    /// `childViewController` swaps between different view controllers.
    func test_childViewController_withNewViewController() {
        let viewController1 = UIViewController()
        subject.childViewController = viewController1
        XCTAssertTrue(subject.children.contains(viewController1))

        let viewController2 = UIViewController()
        subject.childViewController = viewController2
        XCTAssertTrue(subject.children.contains(viewController2))
        XCTAssertFalse(subject.children.contains(viewController1))
    }

    /// `childViewController` removes the current view controller when set to `nil`.
    func test_childViewController_nil() {
        let viewController1 = UIViewController()
        subject.childViewController = viewController1
        XCTAssertTrue(subject.children.contains(viewController1))

        subject.childViewController = nil
        XCTAssertTrue(subject.children.isEmpty)
        XCTAssertTrue(subject.view.subviews.isEmpty)
    }

    /// `preferredStatusBarStyle` returns the preferred status bar style for the given theme.
    func test_preferredStatusBarStyle() {
        subject.theme = .dark
        XCTAssertEqual(subject.preferredStatusBarStyle, .lightContent)

        subject.theme = .default
        XCTAssertEqual(subject.preferredStatusBarStyle, .default)

        subject.theme = .light
        XCTAssertEqual(subject.preferredStatusBarStyle, .darkContent)
    }

    /// `rootViewController` returns itself, instead of the current `childViewController`.
    func test_rootViewController() {
        let viewController = UIViewController()
        subject.childViewController = viewController
        XCTAssertIdentical(subject.rootViewController, subject)
    }

    /// `show(child:)` sets `childViewController` to the `rootViewController` on the child navigator.
    func test_show() {
        let navigator = MockStackNavigator()
        navigator.rootViewController = UIViewController()
        subject.show(child: navigator)
        XCTAssertIdentical(subject.childViewController, navigator.rootViewController)
    }
}
