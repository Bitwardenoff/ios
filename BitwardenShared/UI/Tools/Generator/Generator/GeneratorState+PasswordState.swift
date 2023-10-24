extension GeneratorState {
    /// Data model for the values that can be set for generating a password.
    ///
    struct PasswordState: Equatable {
        // MARK: Types

        /// The type of password to generate.
        ///
        enum PasswordGeneratorType: String, Equatable { // swiftlint:disable:this nesting
            /// Generate a passphrase.
            case passphrase

            /// Generate a password.
            case password

            var rawValue: String {
                switch self {
                case .password:
                    return Localizations.password
                case .passphrase:
                    return Localizations.passphrase
                }
            }

            init?(rawValue: String) {
                switch rawValue {
                case Localizations.password:
                    self = .password
                case Localizations.passphrase:
                    self = .passphrase
                default:
                    return nil
                }
            }
        }

        // MARK: Properties

        /// The type of password to generate.
        var passwordGeneratorType = PasswordGeneratorType.password

        /// A proxy value for getting and setting `passwordGeneratorType` via key path with its raw value.
        var passwordGeneratorTypeValue: String {
            get { passwordGeneratorType.rawValue }
            set {
                guard let passwordGeneratorType = PasswordGeneratorType(rawValue: newValue) else { return }
                self.passwordGeneratorType = passwordGeneratorType
            }
        }

        // MARK: Password Properties

        /// Whether the generated password should avoid ambiguous characters.
        var avoidAmbiguous: Bool = false

        /// Whether the generated password should contain lowercase characters.
        var containsLowercase: Bool = true

        /// Whether the generated password should contain numbers.
        var containsNumbers: Bool = true

        /// Whether the generated password should contain special characters.
        var containsSpecial: Bool = false

        /// Whether the generated password should contain uppercase characters.
        var containsUppercase: Bool = true

        /// The length of the generated password.
        var length: Int = 14

        /// A proxy value for getting and setting `length` as a double value (which is needed for
        /// displaying the slider).
        var lengthDouble: Double {
            get { Double(length) }
            set { length = Int(newValue) }
        }

        /// The minimum number of numbers in the generated password.
        var minimumNumber: Int = 1

        /// The minimum number of special characters in the generated password.
        var minimumSpecial: Int = 1
    }
}
