import UIKit

final class MenuNavigationController: UINavigationController {
    private lazy var menuButton: UIBarButtonItem = {
        UIBarButtonItem(
            title: "メニュー",
            style: .plain,
            target: self,
            action: #selector(openMenu)
        )
    }()
    private lazy var edgePan: UIScreenEdgePanGestureRecognizer = {
        let recognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        recognizer.edges = .left
        return recognizer
    }()
    private var sideMenu: SideMenuViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.prefersLargeTitles = false
        delegate = self
        view.addGestureRecognizer(edgePan)
        updateMenuButton(for: topViewController)
    }

    private func updateMenuButton(for viewController: UIViewController?) {
        guard let viewController else { return }
        let hasLeftItem = viewController.navigationItem.leftBarButtonItem != nil
        let hasLeftItems = (viewController.navigationItem.leftBarButtonItems?.isEmpty == false)
        if !hasLeftItem && !hasLeftItems {
            viewController.navigationItem.leftBarButtonItem = menuButton
            return
        }

        let rightItem = viewController.navigationItem.rightBarButtonItem
        let rightItems = viewController.navigationItem.rightBarButtonItems ?? []
        let hasMenuInRight = rightItems.contains(where: { $0 === menuButton }) || rightItem === menuButton
        if !hasMenuInRight {
            if rightItem == nil && rightItems.isEmpty {
                viewController.navigationItem.rightBarButtonItem = menuButton
            } else {
                var items = rightItems
                if items.isEmpty, let single = rightItem {
                    items = [single]
                }
                items.append(menuButton)
                viewController.navigationItem.rightBarButtonItems = items
            }
        }
    }

    @objc private func openMenu() {
        guard sideMenu == nil else { return }
        let items = buildMenuItems()
        let menu = SideMenuViewController(items: items)
        menu.onDismiss = { [weak self] in
            self?.sideMenu = nil
        }
        sideMenu = menu
        menu.present(in: self)
    }

    @objc private func handleEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        if recognizer.state == .recognized {
            openMenu()
        }
    }

    private func buildMenuItems() -> [SideMenuItem] {
        let palette = ThemeManager.palette()
        let iconColor = palette.text
        let iconHome = UIImage(systemName: "house")?.withTintColor(iconColor, renderingMode: .alwaysOriginal)
        let iconFolder = UIImage(systemName: "folder")?.withTintColor(iconColor, renderingMode: .alwaysOriginal)

        return [
            SideMenuItem(title: "モード選択に戻る", icon: iconHome) { [weak self] in
                self?.dismiss(animated: true)
            },
            SideMenuItem(title: "学習セット", icon: iconFolder) { [weak self] in
                self?.switchRoot(to: self?.makeStoryboardController(identifier: "FolderViewController"))
            }
        ]
    }

    private func makeStoryboardController(identifier: String) -> UIViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: identifier)
    }

    private func switchRoot(to controller: UIViewController?) {
        guard let controller else { return }
        setViewControllers([controller], animated: false)
    }
}

extension MenuNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        updateMenuButton(for: viewController)
    }
}
