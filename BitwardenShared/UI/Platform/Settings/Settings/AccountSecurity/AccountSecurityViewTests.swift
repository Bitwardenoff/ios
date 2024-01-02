import SnapshotTesting
import XCTest

@testable import BitwardenShared

class AccountSecurityViewTests: BitwardenTestCase {
    // MARK: Properties

    var subject = AccountSecurityView(
        store: Store(
            processor: StateProcessor(
                state: AccountSecurityState(
                    isApproveLoginRequestsToggleOn: true,
                    sessionTimeoutValue: .fifteenMinutes
                )
            )
        )
    )

    // MARK: Snapshots

    /// The view renders correctly when showing the custom session timeout field.
    func test_snapshot_customSessionTimeoutField() {
        let subject = AccountSecurityView(
            store: Store(
                processor: StateProcessor(
                    state: AccountSecurityState(
                        isApproveLoginRequestsToggleOn: true,
                        sessionTimeoutValue: .custom
                    )
                )
            )
        )
        assertSnapshot(of: subject, as: .defaultPortrait)
    }

    /// The view renders correctly.
    func test_view_render() {
        assertSnapshot(of: subject, as: .defaultPortrait)
    }
}
