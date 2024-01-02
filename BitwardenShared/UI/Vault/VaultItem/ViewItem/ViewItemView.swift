import BitwardenSdk
import SwiftUI

// MARK: - ViewItemView

/// A view that displays the contents of a vault item.
struct ViewItemView: View {
    // MARK: Private Properties

    /// An environment variable used to open URLs.
    @Environment(\.openURL) private var openURL

    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ViewItemState, ViewItemAction, ViewItemEffect>

    var body: some View {
        LoadingView(state: store.state.loadingState) { state in
            if let viewState = state.viewState {
                details(for: viewState)
            }
        }
        .background(Asset.Colors.backgroundSecondary.swiftUIColor.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                VaultItemManagementMenuView(
                    isCloneEnabled: true, store: store.child(
                        state: { _ in },
                        mapAction: { .morePressed($0) },
                        mapEffect: { _ in .deletePressed }
                    )
                )

                Button {
                    store.send(.dismissPressed)
                } label: {
                    Asset.Images.cancel.swiftUIImage
                        .resizable()
                        .frame(width: 19, height: 19)
                }
                .accessibilityLabel(Localizations.close)
            }
        }
        .task {
            await store.perform(.appeared)
        }
    }

    /// The title of the view
    private var navigationTitle: String {
        Localizations.viewItem
    }

    // MARK: Private Methods

    /// The details of the item. This view wraps all of the different detail views for
    /// the different types of items into one variable, so that the edit button can be
    /// added to all of them at once.
    @ViewBuilder
    private func details(for state: ViewVaultItemState) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ViewItemDetailsView(
                    store: store.child(
                        state: { _ in state },
                        mapAction: { $0 },
                        mapEffect: { $0 }
                    )
                )
            }
            .padding(16)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(Localizations.edit) {
                    store.send(.editPressed)
                }
            }
        }
    }
}

// MARK: Previews

#if DEBUG
struct ViewItemView_Previews: PreviewProvider {
    static var cipher = CipherView(
        id: "123",
        organizationId: nil,
        folderId: nil,
        collectionIds: [],
        key: nil,
        name: "",
        notes: nil,
        type: .login,
        login: .init(
            username: nil,
            password: nil,
            passwordRevisionDate: nil,
            uris: nil,
            totp: nil,
            autofillOnPageLoad: nil
        ),
        identity: nil,
        card: nil,
        secureNote: nil,
        favorite: false,
        reprompt: .none,
        organizationUseTotp: false,
        edit: false,
        viewPassword: false,
        localData: nil,
        attachments: nil,
        fields: nil,
        passwordHistory: nil,
        creationDate: .now,
        deletedDate: nil,
        revisionDate: .now
    )

    static var cardState: CipherItemState {
        var state = CipherItemState(existing: cipher)!
        state.type = CipherType.card
        state.isMasterPasswordRePromptOn = true
        state.name = "Points ALL Day"
        state.notes = "Why are we so consumption focused?"
        state.cardItemState = CardItemState(
            brand: .custom(.americanExpress),
            cardholderName: "Bitwarden User",
            cardNumber: "123456789012345",
            cardSecurityCode: "123",
            expirationMonth: .custom(.feb),
            expirationYear: "3009"
        )
        state.updatedDate = .init(timeIntervalSince1970: 1_695_000_000)
        return state
    }

    static var loginState: CipherItemState {
        var state = CipherItemState(existing: cipher)!
        state.customFields = [
            CustomFieldState(
                linkedIdType: nil,
                name: "Field Name",
                type: .text,
                value: "Value"
            ),
        ]
        state.isMasterPasswordRePromptOn = false
        state.name = "Example"
        state.notes = "This is a long note so that it goes to the next line!"
        state.loginState.password = "Password1!"
        state.updatedDate = .init(timeIntervalSince1970: 1_695_000_000)
        state.loginState.uris = [
            UriState(matchType: .custom(.startsWith), uri: "https://www.example.com"),
            UriState(matchType: .custom(.startsWith), uri: "https://www.example.com/account/login"),
        ]
        state.loginState.username = "email@example.com"
        return state
    }

    static var previews: some View {
        NavigationView {
            ViewItemView(
                store: Store(
                    processor: StateProcessor(
                        state: ViewItemState(
                            loadingState: .loading
                        )
                    )
                )
            )
        }
        .previewDisplayName("Loading")

        cardPreview

        loginPreview
    }

    @ViewBuilder static var cardPreview: some View {
        NavigationView {
            ViewItemView(
                store: Store(
                    processor: StateProcessor(
                        state: ViewItemState(
                            loadingState: .data(cardState)
                        )
                    )
                )
            )
        }
        .previewDisplayName("Card")
    }

    @ViewBuilder static var loginPreview: some View {
        NavigationView {
            ViewItemView(
                store: Store(
                    processor: StateProcessor(
                        state: ViewItemState(
                            loadingState: .data(loginState)
                        )
                    )
                )
            )
        }
        .previewDisplayName("Login")
    }
}
#endif
