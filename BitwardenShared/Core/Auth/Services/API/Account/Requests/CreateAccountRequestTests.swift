import Networking
import XCTest

@testable import BitwardenShared

// MARK: - CreateAccountRequestTests

class CreateAccountRequestTests: BitwardenTestCase {
    // MARK: Properties

    var subjectAuthorizationCode: CreateAccountRequest!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        subjectAuthorizationCode = CreateAccountRequest(
            body: CreateAccountRequestModel(
                email: "example@email.com",
                kdfConfig: KdfConfig(),
                key: "key",
                keys: KeysRequestModel(encryptedPrivateKey: "private"),
                masterPasswordHash: "1a2b3c",
                masterPasswordHint: "hint"
            )
        )
    }

    override func tearDown() {
        super.tearDown()

        subjectAuthorizationCode = nil
    }

    // MARK: Tests

    /// Validate that the method is correct.
    func test_method() {
        let subject = CreateAccountRequest(
            body: CreateAccountRequestModel(
                email: "example@email.com",
                kdfConfig: KdfConfig(),
                key: "key",
                keys: KeysRequestModel(encryptedPrivateKey: "private"),
                masterPasswordHash: "1a2b3c",
                masterPasswordHint: "hint"
            )
        )
        XCTAssertEqual(subject.method, .post)
    }

    /// Validate that the path is correct.
    func test_path() {
        let subject = CreateAccountRequest(
            body: CreateAccountRequestModel(
                email: "example@email.com",
                kdfConfig: KdfConfig(),
                key: "key",
                keys: KeysRequestModel(encryptedPrivateKey: "private"),
                masterPasswordHash: "1a2b3c",
                masterPasswordHint: "hint"
            )
        )
        XCTAssertEqual(subject.path, "/accounts/register")
    }

    /// Validate that the body is not nil.
    func test_body() {
        let subject = CreateAccountRequest(
            body: CreateAccountRequestModel(
                email: "example@email.com",
                kdfConfig: KdfConfig(),
                key: "key",
                keys: KeysRequestModel(encryptedPrivateKey: "private"),
                masterPasswordHash: "1a2b3c",
                masterPasswordHint: "hint"
            )
        )
        XCTAssertNotNil(subject.body)
    }

    /// `validate(_:)` with a `400` status code and captcha error in the response body throws a `.captchaRequired`
    /// error.
    func test_validate_with400CaptchaError() {
        let response = HTTPResponse.failure(
            statusCode: 400,
            body: APITestData.createAccountCaptchaFailure.data
        )

        XCTAssertThrowsError(try subjectAuthorizationCode.validate(response)) { error in
            XCTAssertEqual(
                error as? CreateAccountRequestError,
                .captchaRequired(hCaptchaSiteCode: "bc38c8a2-5311-4e8c-9dfc-49e99f6df417")
            )
        }
    }

    /// `validate(_:)` with a `400` status code but no captcha error does not throw a validation error.
    func test_validate_with400NonCaptchaError() {
        let response = HTTPResponse.failure(
            statusCode: 400,
            body: Data("example data".utf8)
        )

        XCTAssertNoThrow(try subjectAuthorizationCode.validate(response))
    }

    /// `validate(_:)` with a valid response does not throw a validation error.
    func test_validate_with200() {
        let response = HTTPResponse.success(
            body: APITestData.createAccountSuccess.data
        )

        XCTAssertNoThrow(try subjectAuthorizationCode.validate(response))
    }

    // MARK: Init

    /// Validate that the value provided to the init method is correct.
    func test_init_body() {
        let subject = CreateAccountRequest(
            body: CreateAccountRequestModel(
                email: "example@email.com",
                kdfConfig: KdfConfig(),
                key: "key",
                keys: KeysRequestModel(encryptedPrivateKey: "private"),
                masterPasswordHash: "1a2b3c",
                masterPasswordHint: "hint"
            )
        )
        XCTAssertEqual(subject.body?.email, "example@email.com")
    }
}
