import Foundation

/// Errors related to Fido2 flows.
public enum Fido2Error: Error {
    /// The user failed to set up a Bitwarden pin.
    case failedToSetupPin

    /// Thrown when the operation to be performed is invalid under the
    /// current circumstances.
    case invalidOperationError

    /// Thrown when in a flow without user interaction and needs to interact with the user.
    case userInteractionRequired
}
