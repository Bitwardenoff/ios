import Foundation
import Networking

/// API response model for the identity token request.
///
struct IdentityTokenResponseModel: JSONResponse, Equatable {
    static var decoder: JSONDecoder = {
        struct AnyKey: CodingKey {
            var stringValue: String
            var intValue: Int?

            init(stringValue: String) {
                self.stringValue = stringValue
                intValue = nil
            }

            init(intValue: Int) {
                stringValue = String(intValue)
                self.intValue = intValue
            }
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { keys in
            // A custom key decoding strategy that handles snake_case, PascalCase or camelCase.

            let key = keys.last!.stringValue
            let camelCaseKey: String
            if key.contains("_") {
                // Handle snake_case.
                camelCaseKey = key.lowercased()
                    .split(separator: "_")
                    .enumerated()
                    .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() }
                    .joined()
            } else {
                // Handle PascalCase or camelCase.
                camelCaseKey = key.prefix(1).lowercased() + key.dropFirst()
            }
            return AnyKey(stringValue: camelCaseKey)
        }
        return decoder
    }()

    // MARK: Account Properties

    /// Whether the app needs to force a password reset.
    let forcePasswordReset: Bool

    /// The type of KDF algorithm to use.
    let kdf: KdfType

    /// The number of iterations to use when calculating a password hash.
    let kdfIterations: Int

    /// The amount of memory to use when calculating a password hash.
    let kdkMemory: Int?

    /// The number of threads to use when calculating a password hash.
    let kdfParallelism: Int?

    /// The user's key.
    let key: String

    /// Policies related to the user's master password.
    let masterPasswordPolicy: MasterPasswordPolicyResponseModel?

    /// The user's private key.
    let privateKey: String

    /// Whether the user's master password needs to be reset.
    let resetMasterPassword: Bool

    /// Options for a user's decryption.
    let userDecryptionOptions: UserDecryptionOptions?

    // MARK: Token Properties

    /// The user's access token.
    let accessToken: String

    /// The number of seconds before the access token expires.
    let expiresIn: Int

    /// The type of token.
    let tokenType: String

    /// The user's refresh token.
    let refreshToken: String
}
