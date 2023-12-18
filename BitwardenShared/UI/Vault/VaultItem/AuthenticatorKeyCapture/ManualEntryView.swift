import SwiftUI

// MARK: - ManualEntryView

/// A view for the user to manually enter an authenticator key.
///
struct ManualEntryView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ManualEntryState, ManualEntryAction, Void>

    var body: some View {
        content
            .navigationTitle(Localizations.authenticatorKeyScanner)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ToolbarButton(asset: Asset.Images.cancel, label: Localizations.cancel) {
                        store.send(.dismissPressed)
                    }
                }
            }
    }

    /// A button to trigger an `.addPressed(:)` action.
    ///
    private var addButton: some View {
        Button(Localizations.addTotp) {
            store.send(
                ManualEntryAction.addPressed(code: store.state.authenticatorKey)
            )
        }
        .buttonStyle(.tertiary())
    }

    /// The main content of the view.
    ///
    private var content: some View {
        VStack(alignment: .leading, spacing: 16.0) {
            Text(Localizations.enterKeyManually)
                .styleGuide(.title2, weight: .bold)
            BitwardenTextField(
                title: Localizations.authenticatorKey,
                text: store.binding(
                    get: \.authenticatorKey,
                    send: ManualEntryAction.authenticatorKeyChanged
                )
            )
            addButton
            footer
        }
        .background(
            Asset.Colors.backgroundSecondary.swiftUIColor
                .ignoresSafeArea()
        )
        .scrollView()
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Explanation text for the view and a butotn to launch the scan code view.
    ///
    private var footer: some View {
        Group {
            Text(Localizations.onceTheKeyIsSuccessfullyEntered)
                .styleGuide(.callout)
            footerButtonContainer
        }
    }

    /// A view to wrap the button for triggering `.scanCodePressed`.
    ///
    private var footerButtonContainer: some View {
        VStack(alignment: .leading, spacing: 0.0, content: {
            Text(Localizations.cannotAddAuthenticatorKey)
                .styleGuide(.callout)
            Button(
                action: { store.send(.scanCodePressed) },
                label: {
                    Text(Localizations.scanQRCode)
                        .foregroundColor(Asset.Colors.primaryBitwarden.swiftUIColor)
                        .styleGuide(.callout)
                }
            )
            .buttonStyle(InlineButtonStyle())
        })
    }
}

#if DEBUG
struct ManualEntryView_Previews: PreviewProvider {
    struct PreviewState: ManualEntryState {
        var authenticatorKey: String = ""

        var manualEntryState: ManualEntryState {
            self
        }
    }

    static var previews: some View {
        NavigationView {
            ManualEntryView(
                store: Store(
                    processor: StateProcessor(
                        state: PreviewState().manualEntryState
                    )
                )
            )
        }
        .previewDisplayName("Empty")

        NavigationView {
            ManualEntryView(
                store: Store(
                    processor: StateProcessor(
                        state: PreviewState(
                            authenticatorKey: "manualEntry"
                        ).manualEntryState
                    )
                )
            )
        }
        .previewDisplayName("Text Added")
    }
}
#endif
