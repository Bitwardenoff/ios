import BitwardenSdk
import Foundation

// MARK: - ViewItemState

/// The state of a `ViewItemProcessor`.
struct ViewItemState: Equatable {
    // MARK: Types

    /// An enumeration of the possible values of this state.
    enum ItemTypeState: Equatable {
        /// A login item's representative state.
        case login(ViewLoginItemState)
    }

    // MARK: Properties

    /// The current state. If this state is not `.loading`, this value will contain an associated value with the
    /// appropriate internal state.
    var loadingState: LoadingState<ItemTypeState> = .loading
}

extension ViewItemState {
    // MARK: Initialization

    /// Creates a new `ViewItemState` from a provided `CipherView` from the vault.
    ///
    /// - Parameter cipherView: The `CipherView` to create this state with.
    ///
    init?(cipherView: CipherView) {
        switch cipherView.type {
        case .login:
            guard let loginItem = cipherView.login else { return nil }
            self.init(
                loadingState: .data(
                    .login(
                        ViewLoginItemState(
                            customFields: cipherView.fields?.map(CustomFieldState.init) ?? [],
                            folder: cipherView.folderId,
                            isPasswordVisible: false,
                            name: cipherView.name,
                            notes: cipherView.notes,
                            password: loginItem.password,
                            passwordUpdatedDate: loginItem.passwordRevisionDate,
                            updatedDate: cipherView.revisionDate,
                            uris: loginItem.uris ?? [],
                            username: loginItem.username
                        )
                    )
                )
            )
        default:
            return nil
        }
    }
}
