// MARK: - AuthRoute

/// A route to a specific screen in the authentication flow.
public enum AuthRoute: Equatable {
    /// A route to the create account screen.
    case createAccount

    /// A route to the landing screen.
    case landing

    /// A route to the login screen.
    case login

    /// A route to the region selection screen.
    case regionSelection
}
