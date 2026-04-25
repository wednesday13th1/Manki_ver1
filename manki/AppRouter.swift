import UIKit

enum AppRoute: CaseIterable {
    case home
    case folder
    case sets
    case flip
    case test
    case settings

    var title: String {
        switch self {
        case .home: return "ホーム"
        case .folder: return "フォルダー検索"
        case .sets: return "学習セット"
        case .flip: return "フリップ"
        case .test: return "テスト"
        case .settings: return "設定"
        }
    }

    var systemImageName: String {
        switch self {
        case .home: return "house.fill"
        case .folder: return "folder.fill"
        case .sets: return "square.stack.3d.up.fill"
        case .flip: return "rectangle.on.rectangle.angled.fill"
        case .test: return "checkmark.seal.fill"
        case .settings: return "gearshape.fill"
        }
    }

    func menuIcon(tintColor: UIColor) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold, scale: .medium)
        return UIImage(systemName: systemImageName, withConfiguration: configuration)?
            .withTintColor(tintColor, renderingMode: .alwaysOriginal)
    }

    static func route(for viewController: UIViewController?) -> AppRoute? {
        guard let viewController else { return nil }
        switch viewController {
        case is ModeViewController:
            return .home
        case is FolderViewController:
            return .folder
        case is SetViewController:
            return .sets
        case is FlipViewController:
            return .flip
        case is TestViewController, is QuizViewController:
            return .test
        case is SettingViewController:
            return .settings
        default:
            return nil
        }
    }
}

enum AppRouter {
    static func makeViewController(for route: AppRoute, storyboard: UIStoryboard?) -> UIViewController {
        let storyboard = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        switch route {
        case .home:
            return storyboard.instantiateInitialViewController() ?? ModeViewController()
        case .folder:
            return storyboard.instantiateViewController(withIdentifier: "FolderViewController")
        case .sets:
            return SetViewController(folderID: nil, showsAll: true)
        case .flip:
            return storyboard.instantiateViewController(withIdentifier: "FlipViewController")
        case .test:
            return TestViewController()
        case .settings:
            return SettingViewController()
        }
    }

    static func navigate(to route: AppRoute, from navigationController: UINavigationController) {
        if route == .home {
            navigationController.dismiss(animated: true)
            return
        }

        if let existing = navigationController.viewControllers.first(where: { AppRoute.route(for: $0) == route }) {
            navigationController.popToViewController(existing, animated: true)
            return
        }

        let controller = makeViewController(for: route, storyboard: navigationController.storyboard)
        prepare(controller, in: navigationController)
        navigationController.setViewControllers([controller], animated: false)
    }

    static func push(_ controller: UIViewController, from navigationController: UINavigationController, animated: Bool = true) {
        prepare(controller, in: navigationController)
        navigationController.pushViewController(controller, animated: animated)
    }

    private static func prepare(_ controller: UIViewController, in navigationController: UINavigationController) {
        if let setController = controller as? SetViewController {
            setController.prepareForInitialTransition(in: navigationController.view.bounds)
        } else {
            controller.loadViewIfNeeded()
            controller.view.frame = navigationController.view.bounds
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
    }
}
