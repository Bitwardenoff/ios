import BitwardenSdk
import SwiftUI

// MARK: - ViewItemDetailsView

/// A view for displaying the contents of a Vault item details.
struct ViewItemDetailsView: View {
    // MARK: Private Properties

    @Environment(\.openURL) private var openURL

    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<ViewVaultItemState, ViewItemAction, ViewItemEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    // MARK: View

    var body: some View {
        itemInformationSection

        uriSection

        notesSection

        customFieldsSection

        attachmentsSection

        updatedDate
    }

    // MARK: Private Views

    /// The attachments section.
    @ViewBuilder private var attachmentsSection: some View {
        if let attachments = store.state.attachments, !attachments.isEmpty {
            SectionView(Localizations.attachments) {
                VStack(spacing: 0) {
                    ForEach(attachments) { attachment in
                        attachmentRow(attachment, hasDivider: attachment != attachments.last)
                    }
                }
                .cornerRadius(10)
            }
        }
    }

    /// The custom fields section.
    @ViewBuilder private var customFieldsSection: some View {
        if !store.state.customFieldsState.customFields.isEmpty {
            SectionView(Localizations.customFields) {
                ForEach(store.state.customFieldsState.customFields, id: \.self) { customField in
                    if customField.type == .boolean {
                        HStack(spacing: 16) {
                            let image = customField.booleanValue
                                ? Asset.Images.checkSquare.swiftUIImage
                                : Asset.Images.square.swiftUIImage
                            image
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(Asset.Colors.textSecondary.swiftUIColor)

                            Text(customField.name ?? "")
                                .styleGuide(.body)
                        }
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Asset.Colors.backgroundPrimary.swiftUIColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        BitwardenField(title: customField.name) {
                            switch customField.type {
                            case .boolean:
                                EmptyView()
                            case .hidden:
                                if let value = customField.value {
                                    PasswordText(
                                        password: value,
                                        isPasswordVisible: customField.isPasswordVisible
                                    )
                                }
                            case .text:
                                if let value = customField.value {
                                    Text(value)
                                }
                            case .linked:
                                if let linkedIdType = customField.linkedIdType {
                                    HStack(spacing: 8) {
                                        Asset.Images.link.swiftUIImage
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                            .foregroundColor(Asset.Colors.textSecondary.swiftUIColor)
                                        Text(linkedIdType.localizedName)
                                    }
                                }
                            }
                        } accessoryContent: {
                            if let value = customField.value {
                                switch customField.type {
                                case .hidden:
                                    PasswordVisibilityButton(isPasswordVisible: customField.isPasswordVisible) {
                                        store.send(.customFieldVisibilityPressed(customField))
                                    }
                                    Button {
                                        store.send(.copyPressed(value: value))
                                    } label: {
                                        Asset.Images.copy.swiftUIImage
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                case .text:
                                    Button {
                                        store.send(.copyPressed(value: value))
                                    } label: {
                                        Asset.Images.copy.swiftUIImage
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                    }
                                case .boolean, .linked:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// The item information section.
    private var itemInformationSection: some View {
        SectionView(Localizations.itemInformation, contentSpacing: 12) {
            BitwardenTextValueField(title: Localizations.name, value: store.state.name)

            // check for type
            switch store.state.type {
            case .card:
                ViewCardItemView(
                    store: store.child(
                        state: { _ in store.state.cardItemViewState },
                        mapAction: { $0 },
                        mapEffect: nil
                    )
                )
            case .identity:
                ViewIdentityItemView(
                    store: store.child(
                        state: { _ in store.state.identityState },
                        mapAction: { $0 },
                        mapEffect: nil
                    )
                )
            case .login:
                ViewLoginItemView(
                    store: store.child(
                        state: { _ in store.state.loginState },
                        mapAction: { $0 },
                        mapEffect: { $0 }
                    ),
                    timeProvider: timeProvider
                )
            case .secureNote:
                EmptyView()
            }
        }
    }

    /// The notes section.
    @ViewBuilder private var notesSection: some View {
        if !store.state.notes.isEmpty {
            SectionView(Localizations.notes) {
                BitwardenTextValueField(value: store.state.notes)
            }
        }
    }

    /// The updated date footer.
    private var updatedDate: some View {
        VStack(alignment: .leading, spacing: 0) {
            FormattedDateTimeView(label: Localizations.dateUpdated, date: store.state.updatedDate)

            if store.state.type == .login {
                if let passwordUpdatedDate = store.state.loginState.passwordUpdatedDate {
                    FormattedDateTimeView(label: Localizations.datePasswordUpdated, date: passwordUpdatedDate)
                }

                if let passwordHistoryCount = store.state.loginState.passwordHistoryCount, passwordHistoryCount > 0 {
                    HStack(spacing: 4) {
                        Text(Localizations.passwordHistory + ":")

                        Button {
                            store.send(.passwordHistoryPressed)
                        } label: {
                            Text("\(passwordHistoryCount)")
                                .underline(color: Asset.Colors.primaryBitwarden.swiftUIColor)
                        }
                        .foregroundStyle(Asset.Colors.primaryBitwarden.swiftUIColor)
                        .id("passwordHistoryButton")
                    }
                    .accessibilityLabel(Localizations.passwordHistory + ": \(passwordHistoryCount)")
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .styleGuide(.subheadline)
        .multilineTextAlignment(.leading)
        .foregroundColor(Asset.Colors.textSecondary.swiftUIColor)
    }

    /// The URIs section (login only).
    @ViewBuilder private var uriSection: some View {
        if store.state.type == .login, !store.state.loginState.uris.isEmpty {
            SectionView(Localizations.urIs) {
                ForEach(store.state.loginState.uris, id: \.self) { uri in
                    BitwardenTextValueField(title: Localizations.uri, value: uri.uri) {
                        if uri.uri.contains(".com") {
                            Button {
                                guard let url = URL(string: uri.uri) else {
                                    return
                                }
                                openURL(url.sanitized)
                            } label: {
                                Asset.Images.externalLink.swiftUIImage
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            .accessibilityLabel(Localizations.launch)
                        }

                        Button {
                            store.send(.copyPressed(value: uri.uri, field: .uri))
                        } label: {
                            Asset.Images.copy.swiftUIImage
                                .resizable()
                                .frame(width: 16, height: 16)
                        }
                        .accessibilityLabel(Localizations.copy)
                    }
                }
            }
        }
    }

    /// A row to display an existing attachment.
    ///
    /// - Parameters:
    ///   - attachment: The attachment to display.
    ///   - hasDivider: Whether the row should display a divider.
    ///
    private func attachmentRow(_ attachment: AttachmentView, hasDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(attachment.fileName ?? "")
                    .styleGuide(.body)
                    .foregroundStyle(Asset.Colors.textPrimary.swiftUIColor)
                    .lineLimit(1)

                Spacer()

                if let sizeName = attachment.sizeName {
                    Text(sizeName)
                        .styleGuide(.body)
                        .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
                        .lineLimit(1)
                }

                Button {
                    store.send(.downloadAttachment(attachment))
                } label: {
                    Image(uiImage: Asset.Images.download.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(Asset.Colors.primaryBitwarden.swiftUIColor)
                        .frame(width: 22, height: 22)
                }
                .accessibilityLabel(Localizations.download)
            }
            .padding(16)

            if hasDivider {
                Divider()
                    .padding(.leading, 16)
            }
        }
        .background(Asset.Colors.backgroundPrimary.swiftUIColor)
    }
}
