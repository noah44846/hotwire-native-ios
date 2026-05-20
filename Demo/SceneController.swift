import HotwireNative
import SafariServices
import UIKit
import WebKit

final class SceneController: UIResponder {
    var window: UIWindow?

    private let rootURL = Demo.current
    private lazy var tabBarController = HotwireTabBarController(
        navigatorDelegate: self,
        lazyLoadTabs: true
    )

    // MARK: - Authentication

    private func promptForAuthentication() {
        // Clean up empty screen from 401 response.
        tabBarController.activeNavigator.pop(animated: false)

        let authURL = rootURL.appendingPathComponent("/session/new")
        tabBarController.activeNavigator.route(authURL)
    }

    // MARK: - Bug repro: confirm() dismissed externally

    /// Simulates a push-notification deeplink: switches to the first tab and
    /// pushes a new screen onto its navigator. Used by the "JS confirm
    /// dismissed externally" bug repro to dismiss the presenting view
    /// controller (and its alert) while a JS confirm() dialog is on screen.
    private func simulateNotificationDeeplink() {
        tabBarController.selectedIndex = 0
        tabBarController.activeNavigator.route(rootURL.appendingPathComponent("/navigation"))
    }

    private func scheduleNotificationDeeplink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.simulateNotificationDeeplink()
        }
    }
}

extension SceneController: UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        tabBarController.load(HotwireTab.all)
    }
}

extension SceneController: NavigatorDelegate {
    func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
        if proposal.url.path == "/bugs/schedule_deeplink" {
            scheduleNotificationDeeplink()
            return .reject
        }

        switch proposal.viewController {
        case NumbersViewController.pathConfigurationIdentifier:
            return .acceptCustom(NumbersViewController(
                url: proposal.url,
                navigator: navigator
                )
            )

        default:
            return .accept
        }
    }

    func visitableDidFailRequest(_ visitable: any Visitable, error: HotwireNativeError, retryHandler: RetryBlock?) {
        switch error {
        case .http(.client(.unauthorized)):
            promptForAuthentication()
        default:
            if let errorPresenter = visitable as? ErrorPresenter {
                errorPresenter.presentError(error) {
                    retryHandler?()
                }
            } else {
                let alert = UIAlertController(title: "Visit failed!", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                tabBarController.activeNavigator.present(alert, animated: true)
            }
        }
    }
}
