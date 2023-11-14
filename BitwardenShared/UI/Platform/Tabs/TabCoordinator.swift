import SwiftUI
import UIKit

// MARK: - TabCoordinator

/// A coordinator that manages navigation in the tab interface.
///
internal final class TabCoordinator: Coordinator, HasTabNavigator {
    // MARK: Types

    /// The module types required by this coordinator for creating child coordinators.
    typealias Module = GeneratorModule
        & SendModule
        & SettingsModule
        & VaultModule

    // MARK: Properties

    /// The root navigator used to display this coordinator's interface.
    weak var rootNavigator: (any RootNavigator)?

    /// The tab navigator that is managed by this coordinator.
    var tabNavigator: TabNavigator

    // MARK: Private Properties

    /// The coordinator used to navigate to `GeneratorRoute`s.
    private var generatorCoordinator: AnyCoordinator<GeneratorRoute>?

    /// The module used to create child coordinators.
    private let module: Module

    /// The coordinator used to navigate to `SendRoute`s.
    private var sendCoordinator: AnyCoordinator<SendRoute>?

    /// The coordinator used to navigate to `SettingsRoute`s.
    private var settingsCoordinator: AnyCoordinator<SettingsRoute>?

    /// A delegate of the `SettingsCoordinator`.
    private weak var settingsDelegate: SettingsCoordinatorDelegate?

    /// The coordinator used to navigate to `VaultRoute`s.
    private var vaultCoordinator: AnyCoordinator<VaultRoute>?

    // MARK: Initialization

    /// Creates a new `TabCoordinator`.
    ///
    /// - Parameters:
    ///   - module: The module used to create child coordinators.
    ///   - rootNavigator: The root navigator used to display this coordinator's interface.
    ///   - settingsDelegate: A delegate of the `SettingsCoordinator`.
    ///   - tabNavigator: The tab navigator that is managed by this coordinator.
    ///
    init(
        module: Module,
        rootNavigator: RootNavigator,
        settingsDelegate: SettingsCoordinatorDelegate,
        tabNavigator: TabNavigator
    ) {
        self.module = module
        self.rootNavigator = rootNavigator
        self.settingsDelegate = settingsDelegate
        self.tabNavigator = tabNavigator
    }

    // MARK: Methods

    func navigate(to route: TabRoute, context: AnyObject?) {
        tabNavigator.selectedIndex = route.index
        switch route {
        case let .vault(vaultRoute):
            show(vaultRoute: vaultRoute, context: context)
        case .send:
            // TODO: BIT-249 Add show send function for navigating to a send route
            break
        case .generator:
            // TODO: BIT-327 Add show generation function for navigation to a generator route
            break
        case let .settings(settingsRoute):
            settingsCoordinator?.navigate(to: settingsRoute, context: context)
        }
    }

    func show(vaultRoute: VaultRoute, context: AnyObject?) {
        vaultCoordinator?.navigate(to: vaultRoute, context: context)
    }

    func start() {
        guard let rootNavigator, let settingsDelegate else { return }

        rootNavigator.show(child: tabNavigator)

        let vaultNavigator = UINavigationController()
        vaultNavigator.navigationBar.prefersLargeTitles = true
        vaultCoordinator = module.makeVaultCoordinator(
            stackNavigator: vaultNavigator
        )

        let sendNavigator = UINavigationController()
        sendNavigator.navigationBar.prefersLargeTitles = true
        sendCoordinator = module.makeSendCoordinator(
            stackNavigator: sendNavigator
        )
        sendCoordinator?.start()

        let generatorNavigator = UINavigationController()
        generatorNavigator.navigationBar.prefersLargeTitles = true
        generatorCoordinator = module.makeGeneratorCoordinator(
            stackNavigator: generatorNavigator
        )
        generatorCoordinator?.start()

        let settingsNavigator = UINavigationController()
        settingsNavigator.navigationBar.prefersLargeTitles = true
        let settingsCoordinator = module.makeSettingsCoordinator(
            delegate: settingsDelegate,
            stackNavigator: settingsNavigator
        )
        settingsCoordinator.start()
        self.settingsCoordinator = settingsCoordinator

        let tabsAndNavigators: [TabRoute: Navigator] = [
            .vault(.list): vaultNavigator,
            .send: sendNavigator,
            .generator(.generator): generatorNavigator,
            .settings(.settings): settingsNavigator,
        ]
        tabNavigator.setNavigators(tabsAndNavigators)
    }
}
