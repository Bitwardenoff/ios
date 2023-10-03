// MARK: - LandingState

/// An object that defines the current state of a `LandingView`.
///
struct LandingState: Equatable {
    // MARK: Properties

    /// The email address provided by the user.
    var email: String

    /// A flag indicating if the "Remember Me" toggle is on.
    var isRememberMeOn: Bool

    /// The region selected by the user.
    var region: RegionType

    // MARK: Initialization

    /// Creates a new `LandingState`.
    ///
    /// - Parameters:
    ///   - email: The email address provided by the user.
    ///   - isRememberMeOn: A flag indicating if the "Remember Me" toggle is on.
    ///
    init(
        email: String = "",
        isRememberMeOn: Bool = false,
        region: RegionType = .unitedStates
    ) {
        self.email = email
        self.isRememberMeOn = isRememberMeOn
        self.region = region
    }
}
