import Foundation
import Networking

// MARK: - CreateAccountRequest

/// The API request sent when submitting the account keys.
///
struct AccountKeysRequest: Request {
    typealias Response = EmptyResponse
    typealias Body = KeysRequestModel

    /// The body of this request.
    var body: KeysRequestModel?

    /// The HTTP method for this request.
    let method: HTTPMethod = .post

    /// The URL path for this request.
    var path: String = "/accounts/keys"

    /// Creates a new `CreateAccountRequest` instance.
    ///
    /// - Parameter body: The body of the request.
    ///
    init(body: KeysRequestModel) {
        self.body = body
    }
}
