import Combine
import XCTest

@testable import BitwardenShared

final class VaultTimeoutServiceTests: BitwardenTestCase {
    // MARK: Properties

    var cancellables: Set<AnyCancellable>!
    var subject: DefaultVaultTimeoutService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        cancellables = []
        subject = DefaultVaultTimeoutService()
    }

    override func tearDown() {
        super.tearDown()

        cancellables = nil
        subject = nil
    }

    /// Setting the timeoutStore should trigger the `isLockedPublisher` with the new values.
    func test_changeLockStore() {
        let account = Account.fixtureAccountLogin()

        let expectation = XCTestExpectation(description: "timeoutStore didSet should update isLockedSubject")

        var capturedValue: [String: Bool]?
        subject.isLockedSubject
            .sink { value in
                capturedValue = value
                expectation.fulfill()
            }
            .store(in: &cancellables)

        subject.timeoutStore = [
            account.profile.userId: true,
        ]

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(
            capturedValue,
            [
                account.profile.userId: true,
            ]
        )
    }

    /// `isLocked(userId:)` should return true for a locked account.
    func test_isLocked_true() async {
        let account = Account.fixtureAccountLogin()
        subject.timeoutStore = [
            account.profile.userId: true,
        ]
        let isLocked = try? subject.isLocked(userId: account.profile.userId)
        XCTAssertTrue(isLocked!)
    }

    /// `isLocked(userId:)` should return false for an unlocked account.
    func test_isLocked_false() async {
        let account = Account.fixtureAccountLogin()
        subject.timeoutStore = [
            account.profile.userId: false,
        ]
        let isLocked = try? subject.isLocked(userId: account.profile.userId)
        XCTAssertFalse(isLocked!)
    }

    /// `isLocked(userId:)` should throw when no account is found.
    func test_isLocked_notFound() async {
        XCTAssertThrowsError(try subject.isLocked(userId: "123"))
    }

    /// `lockVault(userId:)` should lock an unlocked account.
    func test_lock_unlocked() async {
        let account = Account.fixtureAccountLogin()
        subject.timeoutStore = [
            account.profile.userId: false,
        ]
        subject.lockVault(true, userId: account.profile.userId)
        XCTAssertEqual(
            [
                account.profile.userId: true,
            ],
            subject.timeoutStore
        )
    }

    /// `lockVault(userId:)` preserves the lock status of a locked account.
    func test_lock_locked() async {
        let account = Account.fixtureAccountLogin()
        subject.timeoutStore = [
            account.profile.userId: true,
        ]
        subject.lockVault(true, userId: account.profile.userId)
        XCTAssertEqual(
            [
                account.profile.userId: true,
            ],
            subject.timeoutStore
        )
    }

    /// `lockVault(userId:)` should lock an unknown account.
    func test_lock_notFound() async {
        let account = Account.fixtureAccountLogin()
        subject.timeoutStore = [:]
        subject.lockVault(true, userId: account.profile.userId)
        XCTAssertEqual(
            [
                account.profile.userId: true,
            ],
            subject.timeoutStore
        )
    }

    /// `remove(userId:)` should remove an unlocked account.
    func test_remove_unlocked() async {
        let account = Account.fixtureAccountLogin()
        subject.timeoutStore = [
            account.profile.userId: false,
        ]
        subject.remove(userId: account.profile.userId)
        XCTAssertTrue(subject.timeoutStore.isEmpty)
    }

    /// `remove(userId:)` should remove a locked account.
    func test_remove_locked() async {
        let account = Account.fixtureAccountLogin()
        subject.timeoutStore = [
            account.profile.userId: true,
        ]
        subject.remove(userId: account.profile.userId)
        XCTAssertTrue(subject.timeoutStore.isEmpty)
    }

    /// `remove(userId:)`preserves state when no account matches.
    func test_remove_notFound() async {
        let account = Account.fixtureAccountLogin()
        subject.timeoutStore = [
            account.profile.userId: false,
        ]
        subject.remove(userId: "123")
        XCTAssertEqual(
            [
                account.profile.userId: false,
            ],
            subject.timeoutStore
        )
    }
}
