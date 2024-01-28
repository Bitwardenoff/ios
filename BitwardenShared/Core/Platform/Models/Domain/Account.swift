/// Domain model for a user account.
///
public struct Account: Codable, Equatable, Hashable {
    // MARK: Properties

    /// The account's profile details.
    var profile: AccountProfile

    /// The account's settings.
    var settings: AccountSettings

    /// The account's API tokens.
    var tokens: AccountTokens
}

extension Account {
    // MARK: Computed Properties

    /// The `KdfConfig` for the account.
    var kdf: KdfConfig {
        KdfConfig(
            kdf: profile.kdfType ?? .pbkdf2sha256,
            kdfIterations: profile.kdfIterations ?? Constants.pbkdf2Iterations,
            kdfMemory: profile.kdfMemory,
            kdfParallelism: profile.kdfParallelism
        )
    }

    // MARK: Initialization

    /// Initializes an `Account` from the response of the identity token request.
    ///
    /// - Parameters:
    ///   - identityTokenResponseModel: The response model from the identity token request.
    ///   - environmentUrls: The environment URLs for an account.
    ///
    init(
        identityTokenResponseModel: IdentityTokenResponseModel,
        environmentUrls: EnvironmentUrlData?
    ) throws {
        let tokenPayload = try TokenParser.parseToken(identityTokenResponseModel.accessToken)
        self.init(
            profile: AccountProfile(
                avatarColor: nil,
                email: tokenPayload.email,
                emailVerified: nil,
                forcePasswordResetReason: identityTokenResponseModel.forcePasswordReset ?
                    .adminForcePasswordReset : nil,
                hasPremiumPersonally: tokenPayload.hasPremium,
                kdfIterations: identityTokenResponseModel.kdfIterations,
                kdfMemory: identityTokenResponseModel.kdfMemory,
                kdfParallelism: identityTokenResponseModel.kdfParallelism,
                kdfType: identityTokenResponseModel.kdf,
                name: tokenPayload.name,
                orgIdentifier: nil,
                stamp: nil,
                userDecryptionOptions: identityTokenResponseModel.userDecryptionOptions,
                userId: tokenPayload.userId
            ),
            settings: AccountSettings(
                environmentUrls: environmentUrls
            ),
            tokens: AccountTokens(
                accessToken: identityTokenResponseModel.accessToken,
                refreshToken: identityTokenResponseModel.refreshToken
            )
        )
    }
}

extension Account {
    /// Domain model for an account's profile details.
    ///
    struct AccountProfile: Codable, Equatable, Hashable {
        // MARK: Properties

        /// The account's avatar color.
        var avatarColor: String?

        /// The account's email.
        var email: String

        /// Whether the email has been verified.
        var emailVerified: Bool?

        /// The reasoning for why a forced password reset may be required.
        let forcePasswordResetReason: ForcePasswordResetReason?

        /// Whether the account has premium
        var hasPremiumPersonally: Bool?

        /// The number of iterations to use when calculating a password hash.
        let kdfIterations: Int?

        /// The amount of memory to use when calculating a password hash.
        let kdfMemory: Int?

        /// The number of threads to use when calculating a password hash.
        let kdfParallelism: Int?

        /// The type of KDF algorithm to use.
        let kdfType: KdfType?

        /// The account's name.
        var name: String?

        /// The organization identifier for the account.
        let orgIdentifier: String?

        /// The account's security stamp.
        let stamp: String?

        /// User decryption options for the account.
        let userDecryptionOptions: UserDecryptionOptions?

        /// The user's identifier.
        let userId: String
    }

    /// Domain model for an account's settings.
    struct AccountSettings: Codable, Equatable, Hashable {
        // MARK: Properties

        /// The environment URLs for an account.
        var environmentUrls: EnvironmentUrlData?
    }

    /// Domain model for an account's API tokens.
    ///
    struct AccountTokens: Codable, Equatable, Hashable {
        // MARK: Properties

        /// The account's access token used to authenticate API requests.
        let accessToken: String

        /// The account's refresh token used to acquire a new access token.
        let refreshToken: String
    }
}
