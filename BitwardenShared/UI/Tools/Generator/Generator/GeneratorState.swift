// MARK: - GeneratorType

/// The type of value to generate.
///
public enum GeneratorType: CaseIterable, Equatable, Menuable {
    /// Generate a password or passphrase.
    case password

    /// Generate a username.
    case username

    /// All of the cases to show in the menu.
    public static let allCases: [Self] = [.password, .username]

    var localizedName: String {
        switch self {
        case .password:
            return Localizations.password
        case .username:
            return Localizations.username
        }
    }
}

// MARK: - GeneratorState

/// An object that defines the current state of a `GeneratorView`.
///
struct GeneratorState: Equatable {
    // MARK: Types

    /// The presentation mode for the generator. Used to determine if specific UI elements are shown.
    enum PresentationMode: Equatable {
        /// The generator is being presented in its own tab for a generic generation task.
        case tab

        /// The generator is being presented in place for a specific generation task.
        case inPlace

        /// A flag indicating if the dismiss button is visible.
        var isDismissButtonVisible: Bool {
            switch self {
            case .tab: false
            case .inPlace: true
            }
        }

        /// A flag indicating if the select button is visible.
        var isSelectButtonVisible: Bool {
            switch self {
            case .tab: false
            case .inPlace: true
            }
        }

        /// A flag indicating if the generator type field is visible.
        var isTypeFieldVisible: Bool {
            switch self {
            case .tab: true
            case .inPlace: false
            }
        }
    }

    // MARK: Properties

    /// The type of value to generate.
    var generatorType = GeneratorType.password

    /// The generated value (password, passphrase or username).
    var generatedValue: String = ""

    /// The options used to generate a password.
    var passwordState = PasswordState()

    /// The mode the generator is currently in. This value determines if the UI should show specific
    /// elements.
    var presentationMode: PresentationMode = .tab

    /// A toast message to show in the view.
    var toast: Toast?

    /// The options used to generate a username.
    var usernameState = UsernameState()

    // MARK: Computed Properties

    /// The list of sections to display in the generator form.
    var formSections: [FormSection<Self>] {
        var optionFields: [FormField<Self>]
        switch generatorType {
        case .password:
            switch passwordState.passwordGeneratorType {
            case .passphrase:
                optionFields = [
                    passwordGeneratorTypeField(),
                    stepperField(
                        keyPath: \.passwordState.numberOfWords,
                        range: 3 ... 20,
                        title: Localizations.numberOfWords
                    ),
                    textField(
                        keyPath: \.passwordState.wordSeparator,
                        title: Localizations.wordSeparator
                    ),
                    toggleField(keyPath: \.passwordState.capitalize, title: Localizations.capitalize),
                    toggleField(keyPath: \.passwordState.includeNumber, title: Localizations.includeNumber),
                ]
            case .password:
                optionFields = [
                    passwordGeneratorTypeField(),
                    sliderField(
                        keyPath: \.passwordState.lengthDouble,
                        range: 5 ... 128,
                        title: Localizations.length,
                        step: 1
                    ),
                    toggleField(
                        accessibilityLabel: Localizations.uppercaseAtoZ,
                        keyPath: \.passwordState.containsUppercase,
                        title: "A-Z"
                    ),
                    toggleField(
                        accessibilityLabel: Localizations.lowercaseAtoZ,
                        keyPath: \.passwordState.containsLowercase,
                        title: "a-z"
                    ),
                    toggleField(
                        accessibilityLabel: Localizations.numbersZeroToNine,
                        keyPath: \.passwordState.containsNumbers,
                        title: "0-9"
                    ),
                    toggleField(
                        accessibilityLabel: Localizations.specialCharacters,
                        keyPath: \.passwordState.containsSpecial,
                        title: "!@#$%^&*"
                    ),
                    stepperField(
                        keyPath: \.passwordState.minimumNumber,
                        range: 0 ... 5,
                        title: Localizations.minNumbers
                    ),
                    stepperField(
                        keyPath: \.passwordState.minimumSpecial,
                        range: 0 ... 5,
                        title: Localizations.minSpecial
                    ),
                    toggleField(keyPath: \.passwordState.avoidAmbiguous, title: Localizations.avoidAmbiguousCharacters),
                ]
            }
        case .username:
            optionFields = [
                FormField(fieldType: .menuUsernameGeneratorType(FormMenuField(
                    footer: usernameState.usernameGeneratorType.localizedDescription,
                    keyPath: \.usernameState.usernameGeneratorType,
                    options: UsernameGeneratorType.allCases,
                    selection: usernameState.usernameGeneratorType,
                    title: Localizations.usernameType
                ))),
            ]

            switch usernameState.usernameGeneratorType {
            case .catchAllEmail:
                optionFields.append(contentsOf: [
                    textField(
                        keyboardType: .URL,
                        keyPath: \.usernameState.domain,
                        textContentType: .URL,
                        title: Localizations.domainNameRequiredParenthesis
                    ),
                ])
            case .forwardedEmail:
                optionFields.append(FormField(fieldType: .menuUsernameForwardedEmailService(
                    FormMenuField(
                        keyPath: \.usernameState.forwardedEmailService,
                        options: ForwardedEmailServiceType.allCases,
                        selection: usernameState.forwardedEmailService,
                        title: Localizations.service
                    )
                )))

                switch usernameState.forwardedEmailService {
                case .addyIO:
                    optionFields.append(contentsOf: [
                        textField(
                            isPasswordVisibleKeyPath: \.usernameState.isAPIKeyVisible,
                            keyPath: \.usernameState.addyIOAPIAccessToken,
                            title: Localizations.apiAccessToken
                        ),
                        textField(
                            keyPath: \.usernameState.addyIODomainName,
                            title: Localizations.domainNameRequiredParenthesis
                        ),
                    ])
                case .duckDuckGo:
                    optionFields.append(
                        textField(
                            isPasswordVisibleKeyPath: \.usernameState.isAPIKeyVisible,
                            keyPath: \.usernameState.duckDuckGoAPIKey,
                            title: Localizations.apiKeyRequiredParenthesis
                        )
                    )
                case .fastmail:
                    optionFields.append(
                        textField(
                            isPasswordVisibleKeyPath: \.usernameState.isAPIKeyVisible,
                            keyPath: \.usernameState.fastmailAPIKey,
                            title: Localizations.apiKeyRequiredParenthesis
                        )
                    )
                case .firefoxRelay:
                    optionFields.append(
                        textField(
                            isPasswordVisibleKeyPath: \.usernameState.isAPIKeyVisible,
                            keyPath: \.usernameState.firefoxRelayAPIAccessToken,
                            title: Localizations.apiAccessToken
                        )
                    )
                case .simpleLogin:
                    optionFields.append(
                        textField(
                            isPasswordVisibleKeyPath: \.usernameState.isAPIKeyVisible,
                            keyPath: \.usernameState.simpleLoginAPIKey,
                            title: Localizations.apiKeyRequiredParenthesis
                        )
                    )
                }
            case .plusAddressedEmail:
                optionFields.append(contentsOf: [
                    textField(
                        keyboardType: .emailAddress,
                        keyPath: \.usernameState.email,
                        textContentType: .emailAddress,
                        title: Localizations.emailRequiredParenthesis
                    ),
                ])
            case .randomWord:
                optionFields.append(contentsOf: [
                    toggleField(keyPath: \.usernameState.capitalize, title: Localizations.capitalize),
                    toggleField(keyPath: \.usernameState.includeNumber, title: Localizations.includeNumber),
                ])
            }
        }

        let generatorFields: [FormField<Self>]
        if presentationMode.isTypeFieldVisible {
            generatorFields = [
                generatedValueField(keyPath: \.generatedValue),
                FormField(fieldType: .menuGeneratorType(FormMenuField(
                    keyPath: \.generatorType,
                    options: GeneratorType.allCases,
                    selection: generatorType,
                    title: Localizations.whatWouldYouLikeToGenerate
                ))),
            ]
        } else {
            generatorFields = [
                generatedValueField(keyPath: \.generatedValue),
            ]
        }

        return [
            FormSection(
                fields: generatorFields,
                id: "Generator",
                title: nil
            ),

            FormSection<Self>(
                fields: optionFields,
                id: "Generator Options",
                title: Localizations.options
            ),
        ]
    }

    // MARK: Methods

    /// Updates the state to show a toast for the value that was copied.
    ///
    mutating func showCopiedValueToast() {
        let valueCopied: String
        switch generatorType {
        case .password:
            switch passwordState.passwordGeneratorType {
            case .passphrase:
                valueCopied = Localizations.passphrase
            case .password:
                valueCopied = Localizations.password
            }
        case .username:
            valueCopied = Localizations.username
        }
        toast = Toast(text: Localizations.valueHasBeenCopied(valueCopied))
    }
}
