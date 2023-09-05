import SwiftUI

// MARK: - StackNavigator

/// An object used to navigate between views in a stack interface.
@MainActor
public protocol StackNavigator: Navigator {
    /// Dismisses the view that was presented modally by the navigator.
    ///
    /// - Parameter animated: Whether the transition should be animated.
    func dismiss(animated: Bool)

    /// Pushes a view onto the navigator's stack.
    ///
    /// - Parameters:
    ///   - view: The view to push onto the stack.
    ///   - animated: Whether the transition should be animated.
    ///   - hidesBottomBar: Whether the bottom bar should be hidden when the view is pushed.
    func push<Content: View>(_ view: Content, animated: Bool, hidesBottomBar: Bool)

    /// Pops a view off the navigator's stack.
    ///
    /// - Parameter animated: Whether the transition should be animated.
    func pop(animated: Bool)

    /// Pops all the view controllers on the stack except the root view controller.
    ///
    /// - Parameter animated: Whether the transition should be animated.
    func popToRoot(animated: Bool)

    /// Presents a view modally.
    ///
    /// - Parameters:
    ///   - view: The view to present.
    ///   - animated: Whether the transition should be animated.
    ///   - overFullscreen: Whether or not the presented modal should cover the full screen.
    func present<Content: View>(_ view: Content, animated: Bool, overFullscreen: Bool)

    /// Presents a view controller modally. Supports presenting on top of presented modals if necessary.
    ///
    /// - Parameters:
    ///   - viewController: The view controller to present.
    ///   - animated: Whether the transition should be animated.
    func present(_ viewController: UIViewController, animated: Bool)

    /// Replaces the stack with the specified view.
    ///
    /// - Parameters:
    ///   - view: The view that will replace the stack.
    ///   - animated: Whether the transition should be animated.
    func replace<Content: View>(_ view: Content, animated: Bool)
}

extension StackNavigator {
    /// Pushes a view onto the navigator's stack.
    ///
    /// - Parameters:
    ///   - view: The view to push onto the stack.
    ///   - animated: Whether the transition should be animated.
    func push<Content: View>(_ view: Content, animated: Bool) {
        push(view, animated: animated, hidesBottomBar: false)
    }

    /// Presents a view modally.
    ///
    /// - Parameters:
    ///   - view: The view to present.
    ///   - animated: Whether the transition should be animated.
    func present<Content: View>(_ view: Content, animated: Bool) {
        present(view, animated: animated, overFullscreen: false)
    }
}

// MARK: - UINavigationController

extension UINavigationController: StackNavigator {
    public var rootViewController: UIViewController? {
        self
    }

    public func dismiss(animated: Bool) {
        dismiss(animated: animated, completion: nil)
    }

    public func pop(animated: Bool) {
        popViewController(animated: animated)
    }

    public func popToRoot(animated: Bool) {
        popToRootViewController(animated: animated)
    }

    public func push<Content: View>(_ view: Content, animated: Bool, hidesBottomBar: Bool) {
        let viewController = UIHostingController(rootView: view)
        viewController.hidesBottomBarWhenPushed = hidesBottomBar
        pushViewController(viewController, animated: animated)
    }

    public func present<Content: View>(_ view: Content, animated: Bool, overFullscreen: Bool) {
        let controller = UIHostingController(rootView: view)
        controller.isModalInPresentation = true
        if overFullscreen {
            controller.modalPresentationStyle = .overFullScreen
            controller.view.backgroundColor = .clear
        }
        present(controller, animated: animated)
    }

    public func present(_ viewController: UIViewController, animated: Bool) {
        var presentedChild = presentedViewController
        var availablePresenter: UIViewController? = self
        while presentedChild != nil {
            availablePresenter = presentedChild
            presentedChild = presentedChild?.presentedViewController
        }
        availablePresenter?.present(viewController, animated: animated, completion: nil)
    }

    public func replace<Content: View>(_ view: Content, animated: Bool) {
        setViewControllers([UIHostingController(rootView: view)], animated: animated)
    }
}
