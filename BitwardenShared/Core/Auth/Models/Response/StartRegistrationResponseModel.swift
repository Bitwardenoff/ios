import Foundation
import Networking

// MARK: - StartRegistrationResponseModel

/// The response returned from the API upon sending the verification email.
///
struct StartRegistrationResponseModel: Response {
    // MARK: Properties

    /// The email verification token.
    var token: String?

    init(response: HTTPResponse) {
        token = String(bytes: response.body, encoding: .utf8)
    }
}
