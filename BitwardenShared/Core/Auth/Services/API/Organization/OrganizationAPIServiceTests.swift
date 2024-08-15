import XCTest

@testable import BitwardenShared

class OrganizationAPIServiceTests: BitwardenTestCase {
    // MARK: Properties

    var client: MockHTTPClient!
    var subject: APIService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        client = MockHTTPClient()
        subject = APIService(client: client)
    }

    override func tearDown() {
        super.tearDown()

        client = nil
        subject = nil
    }

    // MARK: Tests

    /// `getOrganizationAutoEnrollStatus(identifier:)` successfully decodes the organization's
    /// auto-enroll status response.
    func test_getOrganizationAutoEnrollStatus() async throws {
        client.result = .httpSuccess(testData: .organizationAutoEnrollStatus)

        let response = try await subject.getOrganizationAutoEnrollStatus(identifier: "ORG_IDENTIFIER")

        XCTAssertEqual(
            response,
            OrganizationAutoEnrollStatusResponseModel(
                id: "af0d946f-8a7c-41eb-af0e-4b2e4e9fb8f5",
                resetPasswordEnabled: true
            )
        )
    }

    /// `getOrganizationKeys(organizationId:)` successfully decodes the organizations keys response.
    func test_getOrganizationKeys() async throws {
        client.result = .httpSuccess(testData: .organizationKeys)

        let response = try await subject.getOrganizationKeys(organizationId: "ORG_ID")

        XCTAssertEqual(
            response,
            OrganizationKeysResponseModel(
                privateKey: nil,
                publicKey: "MIIBIjAN...2QIDAQAB"
            )
        )
    }

    /// `getSingleSignOnDetails(email:)` successfully decodes the single sign on details response.
    func test_getSingleSignOnDetails() async throws {
        client.result = .httpSuccess(testData: .singleSignOnDetails)

        let response = try await subject.getSingleSignOnDetails(email: "example@email.com")

        XCTAssertEqual(
            response,
            SingleSignOnDetailsResponse(organizationIdentifier: "TeamLivefront", ssoAvailable: true)
        )
    }

    /// `leaveOrganization(organizationId:)` removes the user from the organization.
    func test_leaveOrganization() async throws {
        client.result = .httpSuccess(testData: .emptyResponse)

        await assertAsyncDoesNotThrow {
            _ = try await subject.leaveOrganization(organizationId: "1")
        }

        let request = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.url.relativePath, "/api/organizations/1/leave")
        XCTAssertNil(request.body)
    }

    /// `leaveOrganization(organizationId:)` throws an error if the request fails.
    func test_leaveOrganization_httpFailure() async throws {
        client.result = .httpFailure()

        await assertAsyncThrows {
            _ = try await subject.leaveOrganization(organizationId: "1")
        }
    }
}
