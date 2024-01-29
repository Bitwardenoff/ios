import SwiftUI

// MARK: - ExportVaultView

/// A view that allows users to export their vault.
///
struct ExportVaultView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ExportVaultState, ExportVaultAction, ExportVaultEffect>

    // MARK: View

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.state.disableIndividualVaultExport {
                InfoContainer(Localizations.disablePersonalVaultExportPolicyInEffect)
            }

            fileFormatField

            passwordField

            exportVaultButton
        }
        .disabled(store.state.disableIndividualVaultExport)
        .scrollView()
        .navigationBar(title: Localizations.exportVault, titleDisplayMode: .inline)
        .task {
            await store.perform(.loadData)
        }
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }
        }
    }

    // MARK: Private Views

    /// The button to export the vault.
    private var exportVaultButton: some View {
        Button(Localizations.exportVault) {
            store.send(.exportVaultTapped)
        }
        .buttonStyle(.tertiary())
    }

    /// The selector to choose the export file format.
    private var fileFormatField: some View {
        BitwardenMenuField(
            title: Localizations.fileFormat,
            options: ExportFormatType.allCases,
            selection: store.binding(
                get: \.fileFormat,
                send: ExportVaultAction.fileFormatTypeChanged
            )
        )
    }

    /// The password text field.
    private var passwordField: some View {
        BitwardenTextField(
            title: Localizations.masterPassword,
            text: store.binding(
                get: \.passwordText,
                send: ExportVaultAction.passwordTextChanged
            ),
            footer: Localizations.exportVaultMasterPasswordDescription,
            accessibilityIdentifier: "MasterPasswordEntry",
            isPasswordVisible: store.binding(
                get: \.isPasswordVisible,
                send: ExportVaultAction.togglePasswordVisibility
            ),
            passwordVisibilityAccessibilityId: "PasswordVisibilityToggle"
        )
        .textFieldConfiguration(.password)
    }
}

// MARK: - Previews

#Preview {
    ExportVaultView(store: Store(processor: StateProcessor(state: ExportVaultState())))
}

#Preview("Disabled Export") {
    ExportVaultView(
        store: Store(
            processor: StateProcessor(
                state: ExportVaultState(disableIndividualVaultExport: true)
            )
        )
    )
}
