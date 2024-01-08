import BitwardenSdk
import SwiftUI

// MARK: - SendListItemRowState

/// An object representing the visual state of a `SendListItemRowState`.
struct SendListItemRowState: Equatable {
    // MARK: Properties

    /// The item displayed in this row.
    var item: SendListItem

    /// A flag indicating if this row should display a divider on the bottom edge.
    var hasDivider: Bool
}

// MARK: - SendListItemRowAction

/// Actions that can be sent from a `SendListItemRowView`.
enum SendListItemRowAction: Equatable {
    /// The item was pressed.
    case sendListItemPressed(SendListItem)
}

// MARK: - SendListItemView

/// A view that displays details about a `SendListItem`, to be used as a row in a list.
///
struct SendListItemRowView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<SendListItemRowState, SendListItemRowAction, Void>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Button {
                    store.send(.sendListItemPressed(store.state.item))
                } label: {
                    buttonLabel(for: store.state.item)
                }

                if case let .send(sendView) = store.state.item.itemType {
                    optionsMenu(for: sendView)
                }
            }
            .padding(.horizontal, 16)

            if store.state.hasDivider {
                Divider()
                    .padding(.leading, 22 + 16 + 16)
            }
        }
    }

    // MARK: Private Views

    /// The button's label for the specified send.
    ///
    /// - Parameter item: The `SendListItem` to display.
    ///
    @ViewBuilder
    private func buttonLabel(for item: SendListItem) -> some View {
        HStack(spacing: 16) {
            Image(decorative: item.icon)
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
                .padding(.vertical, 19)

            switch item.itemType {
            case let .send(sendView):
                sendLabel(for: sendView)
            case let .group(sendType, count):
                groupLabel(for: sendType, count: count)
            }
        }
    }

    /// The label for a group.
    ///
    /// - Parameters:
    ///   - sendType: The type of sends this group represents.
    ///   - count: The number of sends in this group.
    ///
    @ViewBuilder
    private func groupLabel(for sendType: SendType, count: Int) -> some View {
        Text(sendType.localizedName)
            .styleGuide(.body)
            .foregroundStyle(Asset.Colors.textPrimary.swiftUIColor)

        Spacer()

        Text("\(count)")
            .styleGuide(.body)
            .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
    }

    /// An options menu to display for a send.
    ///
    /// - Parameter sendView: The `SendView` to display a menu for.
    ///
    @ViewBuilder
    private func optionsMenu(for sendView: SendView) -> some View {
        Menu {
            // TODO: BIT-1266 Add Menu items
            Text("Coming soon, in BIT-1266")
        } label: {
            Asset.Images.horizontalKabob.swiftUIImage
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
        }
    }

    /// The label for a send.
    ///
    /// - Parameter sendView: The `SendView` to display.
    ///
    @ViewBuilder
    private func sendLabel(for sendView: SendView) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AccessibleHStack(alignment: .leading, spacing: 8) {
                Text(sendView.name)
                    .styleGuide(.body)
                    .lineLimit(1)
                    .foregroundStyle(Asset.Colors.textPrimary.swiftUIColor)

                HStack(spacing: 8) {
                    if sendView.disabled {
                        Asset.Images.exclamationTriangle.swiftUIImage
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
                    }

                    if !sendView.password.isEmptyOrNil {
                        Asset.Images.key.swiftUIImage
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
                    }

                    if let maxAccessCount = sendView.maxAccessCount,
                       sendView.accessCount >= maxAccessCount {
                        Asset.Images.doNot.swiftUIImage
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
                    }

                    if let expirationDate = sendView.expirationDate, expirationDate < Date() {
                        Asset.Images.clock.swiftUIImage
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
                    }

                    if sendView.deletionDate < Date() {
                        Asset.Images.trash.swiftUIImage
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
                    }
                }
            }

            Text(sendView.revisionDate.formatted(date: .abbreviated, time: .shortened))
                .styleGuide(.subheadline)
                .lineLimit(1)
                .foregroundStyle(Asset.Colors.textSecondary.swiftUIColor)
        }
        .padding(.vertical, 9)

        Spacer()
    }
}

#Preview {
    VStack {
        SendListItemRowView(
            store: Store(
                processor: StateProcessor(
                    state: SendListItemRowState(
                        item: SendListItem(id: "1", itemType: .group(.text, 42)),
                        hasDivider: true
                    )
                )
            )
        )
        SendListItemRowView(
            store: Store(
                processor: StateProcessor(
                    state: SendListItemRowState(
                        item: SendListItem(id: "1", itemType: .group(.file, 42)),
                        hasDivider: true
                    )
                )
            )
        )
        SendListItemRowView(
            store: Store(
                processor: StateProcessor(
                    state: SendListItemRowState(
                        item: SendListItem(
                            id: "3",
                            itemType: .send(.init(
                                id: "3",
                                accessId: "3",
                                name: "All Statuses",
                                notes: nil,
                                key: "",
                                password: "password",
                                type: .text,
                                file: nil,
                                text: nil,
                                maxAccessCount: 1,
                                accessCount: 1,
                                disabled: true,
                                hideEmail: true,
                                revisionDate: Date(),
                                deletionDate: Date(),
                                expirationDate: Date().advanced(by: -1)
                            ))
                        ),
                        hasDivider: true
                    )
                )
            )
        )
        SendListItemRowView(
            store: Store(
                processor: StateProcessor(
                    state: SendListItemRowState(
                        item: SendListItem(
                            id: "4",
                            itemType: .send(.init(
                                id: "4",
                                accessId: "4",
                                name: "No Status",
                                notes: nil,
                                key: "",
                                password: nil,
                                type: .text,
                                file: nil,
                                text: nil,
                                maxAccessCount: nil,
                                accessCount: 0,
                                disabled: false,
                                hideEmail: false,
                                revisionDate: Date(),
                                deletionDate: Date().advanced(by: 100),
                                expirationDate: Date().advanced(by: 100)
                            ))
                        ),
                        hasDivider: false
                    )
                )
            )
        )
    }
}
