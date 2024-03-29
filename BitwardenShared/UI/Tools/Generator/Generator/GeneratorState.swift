// swiftlint:disable file_length

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

    /// Whether there's a password generation policy in effect.
    var isPolicyInEffect = false

    /// The options used to generate a password.
    var passwordState = PasswordState()

    /// The policy options in effect.
    var policyOptions: PasswordGenerationOptions?

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
        let optionFields: [FormField<Self>] = switch generatorType {
        case .password:
            passwordFormFields
        case .username:
            usernameFormFields
        }

        let generatorFields: [FormField<Self>]
        if presentationMode.isTypeFieldVisible {
            generatorFields = [
                generatedValueField(keyPath: \.generatedValue),
                FormField(fieldType: .menuGeneratorType(FormMenuField(
                    accessibilityIdentifier: "GeneratorTypePicker",
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

    /// Returns whether changing the slider value should generate a new value.
    /// - Parameters:
    ///   - value: The updated value of the slider.
    ///   - keyPath: The key path to the field in which the slider value was changed.
    /// - Returns: `true` if a new value should be generated or `false` otherwise.
    ///
    func shouldGenerateNewValueOnSliderValueChanged(_ value: Double, keyPath: KeyPath<GeneratorState, Double>) -> Bool {
        switch keyPath {
        case \.passwordState.lengthDouble:
            guard Int(value) != passwordState.length else { return false }
            let policyMinLength = policyOptions?.length ?? 0
            return Int(value) >= max(policyMinLength, passwordState.minimumLength)
        default:
            return true
        }
    }

    /// Returns whether changing the text value should generate a new value.
    ///
    /// - Parameter keyPath: The key path to the field in which the text value was changed.
    /// - Returns: `true` if a new value should be generated or `false` otherwise.
    ///
    func shouldGenerateNewValueOnTextValueChanged(keyPath: KeyPath<GeneratorState, String>) -> Bool {
        switch keyPath {
        case \.passwordState.wordSeparator:
            true
        default:
            // For most text fields, wait until focus leaves the field before generating a new value.
            false
        }
    }

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

extension GeneratorState {
    /// Returns the list of fields for the password generator.
    ///
    var passwordFormFields: [FormField<Self>] {
        switch passwordState.passwordGeneratorType {
        case .passphrase:
            [
                passwordGeneratorTypeField(),
                stepperField(
                    accessibilityId: "NumberOfWordsLabel",
                    keyPath: \.passwordState.numberOfWords,
                    range: 3 ... 20,
                    title: Localizations.numberOfWords
                ),
                textField(
                    accessibilityId: "WordSeparatorEntry",
                    keyPath: \.passwordState.wordSeparator,
                    title: Localizations.wordSeparator
                ),
                toggleField(
                    accessibilityId: "CapitalizePassphraseToggle",
                    isDisabled: policyOptions?.capitalize != nil,
                    keyPath: \.passwordState.capitalize,
                    title: Localizations.capitalize
                ),
                toggleField(
                    accessibilityId: "IncludeNumbersToggle",
                    isDisabled: policyOptions?.includeNumber != nil,
                    keyPath: \.passwordState.includeNumber,
                    title: Localizations.includeNumber
                ),
            ]
        case .password:
            [
                passwordGeneratorTypeField(),
                sliderField(
                    keyPath: \.passwordState.lengthDouble,
                    range: 5 ... 128,
                    sliderAccessibilityId: "PasswordLengthSlider",
                    sliderValueAccessibilityId: "PasswordLengthLabel",
                    title: Localizations.length,
                    step: 1
                ),
                toggleField(
                    accessibilityId: "UppercaseAtoZToggle",
                    accessibilityLabel: Localizations.uppercaseAtoZ,
                    isDisabled: policyOptions?.uppercase != nil,
                    keyPath: \.passwordState.containsUppercase,
                    title: "A-Z"
                ),
                toggleField(
                    accessibilityId: "LowercaseAtoZToggle",
                    accessibilityLabel: Localizations.lowercaseAtoZ,
                    isDisabled: policyOptions?.lowercase != nil,
                    keyPath: \.passwordState.containsLowercase,
                    title: "a-z"
                ),
                toggleField(
                    accessibilityId: "NumbersZeroToNineToggle",
                    accessibilityLabel: Localizations.numbersZeroToNine,
                    isDisabled: policyOptions?.number != nil,
                    keyPath: \.passwordState.containsNumbers,
                    title: "0-9"
                ),
                toggleField(
                    accessibilityId: "SpecialCharactersToggle",
                    accessibilityLabel: Localizations.specialCharacters,
                    isDisabled: policyOptions?.special != nil,
                    keyPath: \.passwordState.containsSpecial,
                    title: "!@#$%^&*"
                ),
                stepperField(
                    accessibilityId: "MinNumberValueLabel",
                    keyPath: \.passwordState.minimumNumber,
                    range: 0 ... 5,
                    title: Localizations.minNumbers
                ),
                stepperField(
                    accessibilityId: "MinSpecialValueLabel",
                    keyPath: \.passwordState.minimumSpecial,
                    range: 0 ... 5,
                    title: Localizations.minSpecial
                ),
                toggleField(
                    accessibilityId: "AvoidAmbiguousCharsToggle",
                    keyPath: \.passwordState.avoidAmbiguous,
                    title: Localizations.avoidAmbiguousCharacters
                ),
            ]
        }
    }

    /// Returns the list of fields for the username generator.
    ///
    var usernameFormFields: [FormField<Self>] {
        var optionFields: [FormField<Self>] = [
            FormField(fieldType: .menuUsernameGeneratorType(FormMenuField(
                accessibilityIdentifier: "UsernameTypePicker",
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
                    accessibilityId: "CatchAllEmailDomainEntry",
                    keyboardType: .URL,
                    keyPath: \.usernameState.domain,
                    textContentType: .URL,
                    title: Localizations.domainNameRequiredParenthesis
                ),
            ])

            if let emailWebsite = usernameState.emailWebsite {
                optionFields.append(contentsOf: [
                    emailTypeField(keyPath: \.usernameState.catchAllEmailType),
                    FormField(fieldType: .emailWebsite(emailWebsite)),
                ])
            }
        case .forwardedEmail:
            optionFields.append(FormField(fieldType: .menuUsernameForwardedEmailService(
                FormMenuField(
                    accessibilityIdentifier: "ServiceTypePicker",
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
                        accessibilityId: "ForwardedEmailApiSecretEntry",
                        isPasswordVisibleKeyPath: \.usernameState.isAPIKeyVisible,
                        keyPath: \.usernameState.addyIOAPIAccessToken,
                        passwordVisibilityAccessibilityId: "ShowForwardedEmailApiSecretButton",
                        title: Localizations.apiAccessToken
                    ),
                    textField(
                        accessibilityId: "AnonAddyDomainNameEntry",
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
            case .forwardEmail:
                optionFields.append(contentsOf: [
                    textField(
                        accessibilityId: "ForwardedEmailApiSecretEntry",
                        isPasswordVisibleKeyPath: \.usernameState.isAPIKeyVisible,
                        keyPath: \.usernameState.forwardEmailAPIToken,
                        passwordVisibilityAccessibilityId: "ShowForwardedEmailApiSecretButton",
                        title: Localizations.apiKeyRequiredParenthesis
                    ),
                    textField(
                        accessibilityId: "ForwardEmailDomainNameEntry",
                        keyPath: \.usernameState.forwardEmailDomainName,
                        title: Localizations.domainNameRequiredParenthesis
                    ),
                ])
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
                    accessibilityId: "PlusAddressedEmailEntry",
                    keyboardType: .emailAddress,
                    keyPath: \.usernameState.email,
                    textContentType: .emailAddress,
                    title: Localizations.emailRequiredParenthesis
                ),
            ])

            if let emailWebsite = usernameState.emailWebsite {
                optionFields.append(contentsOf: [
                    emailTypeField(keyPath: \.usernameState.plusAddressedEmailType),
                    FormField(fieldType: .emailWebsite(emailWebsite)),
                ])
            }
        case .randomWord:
            optionFields.append(
                contentsOf: [
                    toggleField(
                        accessibilityId: "CapitalizeRandomWordUsernameToggle",
                        keyPath: \.usernameState.capitalize,
                        title: Localizations.capitalize
                    ),
                    toggleField(
                        accessibilityId: "IncludeNumberRandomWordUsernameToggle",
                        keyPath: \.usernameState.includeNumber,
                        title: Localizations.includeNumber
                    ),
                ]
            )
        }

        return optionFields
    }
}
