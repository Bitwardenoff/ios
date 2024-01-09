import BitwardenSdk
import Foundation

// MARK: - ViewItemState

/// The state of a `ViewItemProcessor`.
struct ViewItemState: Equatable {
    // MARK: Properties

    /// The current state. If this state is not `.loading`, this value will contain an associated value with the
    /// appropriate internal state.
    var loadingState: LoadingState<CipherItemState> = .loading

    /// A flag indicating if the user has premium features.
    var hasPremiumFeatures = false

    /// A flag indicating if the master password has been verified yet.
    var hasVerifiedMasterPassword = false

    /// A flag indicating if the master password is required before interacting with this item.
    var isMasterPasswordRequired: Bool {
        guard !hasVerifiedMasterPassword else { return false }
        return switch loadingState {
        case let .data(state):
            state.isMasterPasswordRePromptOn
        case .loading:
            false
        }
    }

    /// A toast message to show in the view.
    var toast: Toast?
}

extension ViewItemState {
    // MARK: Initialization

    /// Creates a new `ViewItemState` from a provided `CipherView` from the vault.
    ///
    /// - Parameters:
    ///   - cipherView: The `CipherView` to create this state with.
    ///   - hasPremium: Does the account have premium features.
    ///   - totpTime: The time provider used to calculate TOTP code expiration.
    ///
    init?(cipherView: CipherView, hasPremium: Bool, totpTime: TOTPTime) {
        guard let cipherItemState = CipherItemState(
            existing: cipherView,
            hasPremium: hasPremium,
            totpTime: totpTime
        ) else { return nil }
        self.init(loadingState: .data(cipherItemState))
    }
}
