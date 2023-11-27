extension GeneratorState {
    /// Data model for the values that can be set for generating a username.
    ///
    struct UsernameState: Equatable {
        // MARK: Properties

        /// The type of username to generate.
        var usernameGeneratorType = UsernameGeneratorType.plusAddressedEmail

        // MARK: Catch All Email Properties

        /// The type of value to use when generating a catch-all email.
        var catchAllEmailType: UsernameEmailType = .random

        /// The user's domain for generating catch all emails.
        var domain: String = ""

        // MARK: Forwarded Email Properties

        /// The addy.io API access token to generate a forwarded email alias.
        var addyIOAPIAccessToken: String = ""

        /// The domain name used to generate a forwarded email alias with addy.io.
        var addyIODomainName: String = ""

        /// The DuckDuckGo API key used to generate a forwarded email alias.
        var duckDuckGoAPIKey: String = ""

        /// The Fastmail API Key used to generate a forwarded email alias.
        var fastmailAPIKey: String = ""

        /// The Firefox Relay API access token used to generate a forwarded email alias.
        var firefoxRelayAPIAccessToken: String = ""

        /// The service used to generate a forwarded email alias.
        var forwardedEmailService = ForwardedEmailServiceType.addyIO

        /// Whether the service's API key is visible or not.
        var isAPIKeyVisible = false

        /// The simple login API key used to generate a forwarded email alias.
        var simpleLoginAPIKey: String = ""

        // MARK: Plus Addressed Email Properties

        /// The user's email for generating plus addressed emails.
        var email: String = ""

        /// The type of value to use when generating a plus-addressed email.
        var plusAddressedEmailType: UsernameEmailType = .random

        // MARK: Random Word Properties

        /// Whether to capitalize the random word.
        var capitalize: Bool = false

        /// Whether the random word should include numbers.
        var includeNumber: Bool = false

        // MARK: Methods

        /// Updates the state based on the user's persisted username generation options.
        ///
        /// - Parameter options: The user's saved options.
        ///
        mutating func update(with options: UsernameGenerationOptions) {
            usernameGeneratorType = options.type ?? usernameGeneratorType

            // Catch All Properties
            catchAllEmailType = options.catchAllEmailType ?? catchAllEmailType
            domain = options.catchAllEmailDomain ?? domain

            // Forwarded Email Properties
            addyIOAPIAccessToken = options.anonAddyApiAccessToken ?? addyIOAPIAccessToken
            addyIODomainName = options.anonAddyDomainName ?? addyIODomainName
            duckDuckGoAPIKey = options.duckDuckGoApiKey ?? duckDuckGoAPIKey
            fastmailAPIKey = options.fastMailApiKey ?? fastmailAPIKey
            firefoxRelayAPIAccessToken = options.firefoxRelayApiAccessToken ?? firefoxRelayAPIAccessToken
            forwardedEmailService = options.serviceType ?? forwardedEmailService
            simpleLoginAPIKey = options.simpleLoginApiKey ?? simpleLoginAPIKey

            // Plus Address Email Properties
            email = options.plusAddressedEmail ?? email
            plusAddressedEmailType = options.plusAddressedEmailType ?? plusAddressedEmailType

            // Random Word Properties
            capitalize = options.capitalizeRandomWordUsername ?? capitalize
            includeNumber = options.includeNumberRandomWordUsername ?? includeNumber
        }
    }
}

extension GeneratorState.UsernameState {
    /// Returns a `UsernameGenerationOptions` containing the user selected settings for generating
    /// a username used to persist the options between app launches.
    var usernameGenerationOptions: UsernameGenerationOptions {
        UsernameGenerationOptions(
            anonAddyApiAccessToken: addyIOAPIAccessToken.nilIfEmpty,
            anonAddyDomainName: addyIODomainName.nilIfEmpty,
            capitalizeRandomWordUsername: capitalize,
            catchAllEmailDomain: domain.nilIfEmpty,
            catchAllEmailType: catchAllEmailType,
            duckDuckGoApiKey: duckDuckGoAPIKey.nilIfEmpty,
            fastMailApiKey: fastmailAPIKey.nilIfEmpty,
            firefoxRelayApiAccessToken: firefoxRelayAPIAccessToken.nilIfEmpty,
            includeNumberRandomWordUsername: includeNumber,
            plusAddressedEmail: email.nilIfEmpty,
            plusAddressedEmailType: plusAddressedEmailType,
            serviceType: forwardedEmailService,
            simpleLoginApiKey: simpleLoginAPIKey.nilIfEmpty,
            type: usernameGeneratorType
        )
    }
}
