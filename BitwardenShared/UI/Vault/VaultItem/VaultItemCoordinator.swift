import SwiftUI

// MARK: - VaultItemCoordinator

/// A coordinator that manages navigation for displaying, editing, and adding individual vault items.
///
class VaultItemCoordinator: Coordinator, HasStackNavigator {
    // MARK: Types

    typealias Module = GeneratorModule

    typealias Services = HasCameraAuthorizationService
        & HasVaultRepository
        & GeneratorCoordinator.Services

    // MARK: - Private Properties

    /// The module used by this coordinator to create child coordinators.
    private let module: Module

    /// The services used by this coordinator.
    private let services: Services

    // MARK: Properties

    /// The stack navigator that is managed by this coordinator.
    var stackNavigator: StackNavigator

    // MARK: Initialization

    /// Creates a new `VaultCoordinator`.
    ///
    /// - Parameters:
    ///   - module: The module used by this coordinator to create child coordinators.
    ///   - services: The services used by this coordinator.
    ///   - stackNavigator: The stack navigator that is managed by this coordinator.
    ///
    init(
        module: Module,
        services: Services,
        stackNavigator: StackNavigator
    ) {
        self.module = module
        self.services = services
        self.stackNavigator = stackNavigator
    }

    func navigate(to route: VaultItemRoute, context: AnyObject?) {
        switch route {
        case let .addItem(group):
            showAddItem(for: group.flatMap(CipherType.init))
        case let .alert(alert):
            stackNavigator.present(alert)
        case .dismiss:
            stackNavigator.dismiss()
        case let .generator(type, emailWebsite):
            guard let delegate = context as? GeneratorCoordinatorDelegate else { return }
            showGenerator(for: type, emailWebsite: emailWebsite, delegate: delegate)
        case .setupTotpCamera:
            showCamera()
        case .setupTotpManual:
            showManualTotp()
        case let .viewItem(id):
            showViewItem(id: id)
        }
    }

    func start() {}

    // MARK: Private Methods

    /// Shows the add item screen.
    ///
    /// - Parameter type: An optional `CipherType` to initialize this view with.
    ///
    private func showAddItem(for type: CipherType?) {
        let state = AddItemState(
            type: type ?? .login
        )
        let processor = AddItemProcessor(
            coordinator: asAnyCoordinator(),
            services: services,
            state: state
        )
        let store = Store(processor: processor)
        let view = AddItemView(store: store)
        stackNavigator.replace(view)
    }

    /// Shows the totp camera setup screen.
    ///
    private func showCamera() {
        // TODO: BIT-874 Update to show the actual camera screen
        let view = Text("Camera")
        stackNavigator.present(view)
    }

    /// Shows the totp manual setup screen.
    ///
    private func showManualTotp() {
        let view = Text("Manual Totp")
        stackNavigator.present(view)
    }

    /// Shows the generator screen for the the specified type.
    ///
    /// - Parameters:
    ///   - type: The type to generate.
    ///   - emailWebsite: An optional website host used to generate usernames.
    ///   - delegate: The delegate for this generator flow.
    ///
    private func showGenerator(
        for type: GeneratorType,
        emailWebsite: String?,
        delegate: GeneratorCoordinatorDelegate
    ) {
        let navigationController = UINavigationController()
        let coordinator = module.makeGeneratorCoordinator(
            delegate: delegate,
            stackNavigator: navigationController
        )
        coordinator.start()
        coordinator.navigate(to: .generator(staticType: type, emailWebsite: emailWebsite))
        stackNavigator.present(navigationController)
    }

    /// Shows the view item screen.
    ///
    /// - Parameter id: The id of the item to show.
    ///
    private func showViewItem(id: String) {
        let processor = ViewItemProcessor(
            coordinator: self,
            itemId: id,
            services: services,
            state: ViewItemState()
        )
        let store = Store(processor: processor)
        let view = ViewItemView(store: store)
        stackNavigator.replace(view)
    }
}
