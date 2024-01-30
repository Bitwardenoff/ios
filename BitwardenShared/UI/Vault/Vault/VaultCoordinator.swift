import BitwardenSdk
import SwiftUI

// MARK: - VaultCoordinatorDelegate

/// An object that is signaled when specific circumstances in the application flow have been encountered.
///
@MainActor
public protocol VaultCoordinatorDelegate: AnyObject {
    /// Called when the user locks their vault.
    ///
    /// - Parameter account: The user's account.
    ///
    func didLockVault(account: Account)

    /// Called when the user has been logged out.
    ///
    /// - Parameters:
    ///   - userInitiated: Did a user action initiate this logout.
    ///   - otherAccounts: An optional array of the user's other accounts.
    ///
    func didLogout(userInitiated: Bool, otherAccounts: [Account]?)

    /// Called when the user taps add account.
    ///
    func didTapAddAccount()

    /// Called when the user taps selects alternate account.
    ///
    ///  - Parameter userId: The userId of the selected account.
    ///
    func didTapAccount(userId: String)

    /// Present the login request view.
    ///
    /// - Parameter loginRequest: The login request.
    ///
    func presentLoginRequest(_ loginRequest: LoginRequest)
}

// MARK: - VaultCoordinator

/// A coordinator that manages navigation in the vault tab.
///
final class VaultCoordinator: Coordinator, HasStackNavigator {
    // MARK: Types

    typealias Module = GeneratorModule
        & VaultItemModule

    typealias Services = HasAuthRepository
        & HasAuthService
        & HasCameraService
        & HasEnvironmentService
        & HasErrorReporter
        & HasStateService
        & HasTimeProvider
        & HasVaultRepository
        & VaultItemCoordinator.Services

    // MARK: Private Properties

    /// The delegate for this coordinator, used to notify when the user logs out.
    private weak var delegate: VaultCoordinatorDelegate?

    // MARK: - Private Properties

    /// A delegate used to communicate with the app extension.
    private weak var appExtensionDelegate: AppExtensionDelegate?

    /// The module used by this coordinator to create child coordinators.
    private let module: Module

    /// The services used by this coordinator.
    private let services: Services

    // MARK: Properties

    /// The stack navigator that is managed by this coordinator.
    private(set) weak var stackNavigator: StackNavigator?

    // MARK: Initialization

    /// Creates a new `VaultCoordinator`.
    ///
    /// - Parameters:
    ///   - appExtensionDelegate: A delegate used to communicate with the app extension.
    ///   - delegate: The delegate for this coordinator, relays user interactions with the profile switcher.
    ///   - module: The module used by this coordinator to create child coordinators.
    ///   - services: The services used by this coordinator.
    ///   - stackNavigator: The stack navigator that is managed by this coordinator.
    ///
    init(
        appExtensionDelegate: AppExtensionDelegate?,
        delegate: VaultCoordinatorDelegate,
        module: Module,
        services: Services,
        stackNavigator: StackNavigator
    ) {
        self.appExtensionDelegate = appExtensionDelegate
        self.module = module
        self.services = services
        self.stackNavigator = stackNavigator
        self.delegate = delegate
    }

    // MARK: Methods

    func navigate(to route: VaultRoute, context: AnyObject?) {
        switch route {
        case .addAccount:
            delegate?.didTapAddAccount()
        case let .addItem(allowTypeSelection, group, uri):
            Task {
                let hasPremium = try? await services.vaultRepository.doesActiveAccountHavePremium()
                showVaultItem(
                    route: .addItem(
                        allowTypeSelection: allowTypeSelection,
                        group: group,
                        hasPremium: hasPremium ?? false,
                        uri: uri
                    )
                )
            }
        case let .alert(alert):
            stackNavigator?.present(alert)
        case .autofillList:
            showAutofillList()
        case let .editItem(cipher):
            Task {
                let hasPremium = try? await services.vaultRepository.doesActiveAccountHavePremium()
                showVaultItem(
                    route: .editItem(cipher, hasPremium ?? false),
                    delegate: context as? CipherItemOperationDelegate
                )
            }
        case .dismiss:
            stackNavigator?.dismiss()
        case let .group(content):
            showGroup(content)
        case .list:
            showList()
        case let .loginRequest(loginRequest):
            delegate?.presentLoginRequest(loginRequest)
        case let .lockVault(account):
            delegate?.didLockVault(account: account)
        case let .logout(userInitiated):
            Task {
                let accounts = try? await services.stateService.getAccounts()
                delegate?.didLogout(userInitiated: userInitiated, otherAccounts: accounts)
            }
        case let .viewItem(id):
            showVaultItem(route: .viewItem(id: id), delegate: context as? CipherItemOperationDelegate)
        case let .switchAccount(userId: userId):
            delegate?.didTapAccount(userId: userId)
        }
    }

    func start() {}

    // MARK: Private Methods

    /// Shows the autofill list screen.
    ///
    private func showAutofillList() {
        let processor = VaultAutofillListProcessor(
            appExtensionDelegate: appExtensionDelegate,
            coordinator: asAnyCoordinator(),
            services: services,
            state: VaultAutofillListState()
        )
        let view = VaultAutofillListView(store: Store(processor: processor))
        stackNavigator?.replace(view)
    }

    /// Shows the vault group screen.
    ///
    private func showGroup(_ content: VaultGroupContent) {
        let processor = VaultGroupProcessor(
            coordinator: asAnyCoordinator(),
            services: services,
            state: VaultGroupState(
                group: content.group,
                iconBaseURL: services.environmentService.iconsURL,
                searchVaultFilterType: content.filter,
                vaultFilterType: content.filter
            )
        )
        processor.vaultFilterDelegate = content.filterDelegate
        let store = Store(processor: processor)
        let searchHandler = GroupSearchHandler(store: store)
        let view = VaultGroupView(
            searchHandler: searchHandler,
            store: store,
            timeProvider: services.timeProvider
        )
        let viewController = UIHostingController(rootView: view)
        let searchController = UISearchController()
        searchController.searchResultsUpdater = searchHandler

        stackNavigator?.push(
            viewController,
            navigationTitle: content.group.navigationTitle,
            searchController: searchController
        )
    }

    /// Shows the vault list screen.
    ///
    private func showList() {
        let processor = VaultListProcessor(
            coordinator: asAnyCoordinator(),
            services: services,
            state: VaultListState(
                iconBaseURL: services.environmentService.iconsURL
            )
        )
        let store = Store(processor: processor)
        let view = VaultListView(
            store: store,
            timeProvider: services.timeProvider
        )
        stackNavigator?.replace(view, animated: false)
    }

    /// Presents a vault item coordinator, which will navigate to the provided route.
    ///
    /// - Parameter route: The route to navigate to in the coordinator.
    ///
    private func showVaultItem(route: VaultItemRoute, delegate: CipherItemOperationDelegate? = nil) {
        let navigationController = UINavigationController()
        let coordinator = module.makeVaultItemCoordinator(stackNavigator: navigationController)
        coordinator.start()
        coordinator.navigate(to: route, context: delegate)

        stackNavigator?.present(navigationController)
    }
}

/// A protocol to share vault filter settings between screens.
///
public protocol VaultFilterDelegate: AnyObject {
    /// A method to inform the delegate that the vault filter has changed.
    ///
    /// - Parameter newFilter: The up to date vault filter.
    ///
    func didSetVaultFilter(_ newFilter: VaultFilterType)
}
