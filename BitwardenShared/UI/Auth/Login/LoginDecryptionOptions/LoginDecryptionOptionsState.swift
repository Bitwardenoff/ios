// MARK: - LoginDecryptionOptionsState

/// An object that defines the current state of a `LoginDecryptionOptionsView`.
///
struct LoginDecryptionOptionsState: Equatable {
    // MARK: Properties

    /// Whether the approve with master password button is enabled.
    var approveWithMasterPasswordEnabled: Bool = false

    /// Whether the approve with other device button is enabled.
    var approveWithOtherDeviceEnabled: Bool = false

    /// Whether the continue button is enabled.
    var continueButtonEnabled: Bool = false

    /// Email of the active user to be displayed
    var email: String = ""

    /// Whether the remeber device toggle is on.
    var isRememberDeviceToggleOn: Bool = true

    /// The organization identifier being used during the single-sign process.
    var orgIdentifier: String?

    /// Whether the request admin approval button is enabled.
    var requestAdminApprovalEnabled: Bool = false

    /// A toast message to show in the view.
    var toast: Toast?
}
