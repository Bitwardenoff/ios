// MARK: - SendListProcessor

/// The processor used to manage state and handle actions for the send tab list screen.
///
final class SendListProcessor: StateProcessor<SendListState, SendListAction, SendListEffect> {
    // MARK: Types

    typealias Services = HasErrorReporter
        & HasSendRepository

    // MARK: Private properties

    /// The `Coordinator` that handles navigation.
    private let coordinator: AnyCoordinator<SendRoute>

    /// The services required by this processor.
    private let services: Services

    // MARK: Initialization

    /// Creates a new `SendListProcessor`.
    ///
    /// - Parameters:
    ///   - coordinator: The `Coordinator` that handles navigation.
    ///   - services: The services required by this processor.
    ///   - state: The initial state of the processor.
    ///
    init(
        coordinator: AnyCoordinator<SendRoute>,
        services: Services,
        state: SendListState
    ) {
        self.coordinator = coordinator
        self.services = services
        super.init(state: state)
    }

    // MARK: Methods

    override func perform(_ effect: SendListEffect) async {
        switch effect {
        case .appeared:
            await streamSendList()
        case .refresh:
            do {
                try await services.sendRepository.fetchSync(isManualRefresh: true)
            } catch {
                // TODO: BIT-1034 Add an error alert
                print("error: \(error)")
            }
        }
    }

    override func receive(_ action: SendListAction) {
        switch action {
        case .addItemPressed:
            coordinator.navigate(to: .addItem)
        case .clearInfoUrl:
            state.infoUrl = nil
        case .infoButtonPressed:
            state.infoUrl = ExternalLinksConstants.sendInfo
        case let .searchTextChanged(newValue):
            state.searchText = newValue
        case let .sendListItemRow(rowAction):
            switch rowAction {
            case let .sendListItemPressed(item):
                switch item.itemType {
                case let .send(sendView):
                    coordinator.navigate(to: .edit(sendView))
                case .group:
                    // TODO: BIT-1412 Navigate to the group list screen
                    break
                }
            }
        }
    }

    // MARK: Private Methods

    /// Stream the list of sends.
    private func streamSendList() async {
        do {
            for try await sections in try await services.sendRepository.sendListPublisher() {
                state.sections = sections
            }
        } catch {
            services.errorReporter.log(error: error)
        }
    }
}
