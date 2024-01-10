import Foundation

// MARK: ViewLoginItemState

protocol ViewLoginItemState: Sendable {
    // MARK: Properties

    /// The TOTP Key.
    var authenticatorKey: String? { get }

    /// Whether the user has permissions to view the cipher's password.
    var canViewPassword: Bool { get }

    /// A flag indicating if the TOTP feature is available.
    var isTOTPAvailable: Bool { get }

    /// A flag indicating if the password field is visible.
    var isPasswordVisible: Bool { get }

    /// The password for this item.
    var password: String { get }

    /// The date the password was last updated.
    var passwordUpdatedDate: Date? { get }

    /// A model to provide reference times for TOTP code exipration
    var time: TOTPTime { get }

    /// The TOTP code model
    var totpCode: TOTPCodeModel? { get }

    /// The uris associated with this item. Used with autofill.
    var uris: [UriState] { get }

    /// The username for this item.
    var username: String { get }
}
