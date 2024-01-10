/// An object that defines the current state of a `VaultUnlockView`.
///
struct VaultUnlockState: Equatable {
    // MARK: Properties

    /// The user's email for the active account.
    let email: String

    /// Whether the view is being displayed in the app extension.
    var isInAppExtension = false

    /// A flag indicating if the master password should be revealed or not.
    var isMasterPasswordRevealed = false

    var isPinRevealed = false

    /// The master password provided by the user.
    var masterPassword: String = ""

    /// The PIN provided by the user.
    var pin: String = ""

    /// The user's current account profile state and alternative accounts.
    var profileSwitcherState: ProfileSwitcherState

    let unlockMethod: UnlockMethod

    /// The hostname of the web vault URL.
    let webVaultHost: String

    enum UnlockMethod {
        case password
        case pin
    }
}

extension VaultUnlockState {
    // MARK: Initialization

    /// Initialize `VaultUnlockState` for an account.
    ///
    /// - Parameters:
    ///   - account: The active account.
    ///   - profileSwitcherState: State for the profile switcher.
    ///
    init(
        account: Account,
        profileSwitcherState: ProfileSwitcherState = .empty(),
        unlockMethod: UnlockMethod
    ) {
        self.init(
            email: account.profile.email,
            profileSwitcherState: profileSwitcherState,
            unlockMethod: unlockMethod,
            webVaultHost: account.settings.environmentUrls?.webVaultHost ?? Constants.defaultWebVaultHost
        )
    }
}
