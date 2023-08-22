import BitwardenShared
import SwiftUI

final class MockStackNavigator: StackNavigator {
    struct NavigationAction {
        var type: NavigationType
        var view: Any?
        var animated: Bool
        var overFullscreen: Bool?
    }

    enum NavigationType {
        case dismissed
        case pushed
        case popped
        case poppedToRoot
        case presented
        case presentedInSheet
        case replaced
    }

    var actions: [NavigationAction] = []
    var rootViewController: UIViewController?

    func dismiss(animated: Bool) {
        actions.append(NavigationAction(type: .dismissed, animated: animated))
    }

    func push<Content: View>(_ view: Content, animated: Bool, hidesBottomBar: Bool) {
        actions.append(NavigationAction(type: .pushed, view: view, animated: animated))
    }

    func pop(animated: Bool) {
        actions.append(NavigationAction(type: .popped, animated: animated))
    }

    func popToRoot(animated: Bool) {
        actions.append(NavigationAction(type: .poppedToRoot, animated: animated))
    }

    func present<Content: View>(_ view: Content, animated: Bool, overFullscreen: Bool) {
        actions.append(NavigationAction(type: .presented,
                                        view: view,
                                        animated: animated,
                                        overFullscreen: overFullscreen))
    }

    func present(_ viewController: UIViewController, animated: Bool) {
        actions.append(NavigationAction(type: .presented, view: viewController, animated: animated))
    }

    func replace<Content: View>(_ view: Content, animated: Bool) {
        actions.append(NavigationAction(type: .replaced, view: view, animated: animated))
    }
}
