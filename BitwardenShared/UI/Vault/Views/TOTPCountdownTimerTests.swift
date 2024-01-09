import XCTest

@testable import BitwardenShared

final class TOTPCountdownTimerTests: BitwardenTestCase {
    // MARK: Properties

    var subject: TOTPCountdownTimer!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        subject = TOTPCountdownTimer(
            totpCode: .init(
                code: "123456",
                date: .distantPast,
                period: 30
            ),
            onExpiration: {}
        )
    }

    override func tearDown() {
        super.tearDown()
        subject = nil
    }

    func test_onExpiration_oldDate() {
        var didExpire = false
        subject = TOTPCountdownTimer(
            totpCode: .init(
                code: "123456",
                date: .distantPast,
                period: 3
            ),
            onExpiration: {
                didExpire = true
            }
        )
        waitFor(didExpire)
        XCTAssertTrue(didExpire)
    }
}
