import Networking

// MARK: - PreLoginRequest

/// The API request sent when submitting the pre-login information.
///
struct PreLoginRequest: Request {
    typealias Response = PreLoginResponseModel

    let body: PreLoginRequestModel?

    let method = HTTPMethod.post

    let path: String = "/accounts/prelogin"

    /// Creates a new `PreLoginRequest`.
    ///
    /// - Parameter body: The body of this request.
    ///
    init(body: PreLoginRequestModel) {
        self.body = body
    }
}
