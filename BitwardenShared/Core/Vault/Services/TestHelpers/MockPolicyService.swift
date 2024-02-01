@testable import BitwardenShared

class MockPolicyService: PolicyService {
    var applyPasswordGenerationOptionsCalled = false
    var applyPasswordGenerationOptionsResult = false
    var applyPasswordGenerationOptionsTransform = { (_: inout PasswordGenerationOptions) in }

    var isSendHideEmailDisabledByPolicy = false

    var fetchTimeoutPolicyValuesResult: Result<(SessionTimeoutAction?, Int), Error> = .success(
        (SessionTimeoutAction.lock, 60)
    )

    var policyAppliesToUserResult = [PolicyType: Bool]()
    var policyAppliesToUserPolicies = [PolicyType]()

    var replacePoliciesPolicies = [PolicyResponseModel]()
    var replacePoliciesUserId: String?
    var replacePoliciesResult: Result<Void, Error> = .success(())

    func applyPasswordGenerationPolicy(options: inout PasswordGenerationOptions) async throws -> Bool {
        applyPasswordGenerationOptionsCalled = true
        applyPasswordGenerationOptionsTransform(&options)
        return applyPasswordGenerationOptionsResult
    }

    func isSendHideEmailDisabledByPolicy() async -> Bool {
        isSendHideEmailDisabledByPolicy
    }

    func fetchTimeoutPolicyValues() async throws -> (
        action: SessionTimeoutAction?,
        value: Int
    )? {
        try fetchTimeoutPolicyValuesResult.get()
    }

    func policyAppliesToUser(_ policyType: PolicyType) async -> Bool {
        policyAppliesToUserPolicies.append(policyType)
        return policyAppliesToUserResult[policyType] ?? false
    }

    func replacePolicies(_ policies: [PolicyResponseModel], userId: String) async throws {
        replacePoliciesPolicies = policies
        replacePoliciesUserId = userId
        try replacePoliciesResult.get()
    }
}
