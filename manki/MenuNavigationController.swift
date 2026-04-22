import UIKit

final class MenuNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    private lazy var edgePan: UIScreenEdgePanGestureRecognizer = {
        let recognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        recognizer.edges = .left
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()
    private lazy var floatingMenuButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
        button.accessibilityLabel = "メニュー"
        button.addTarget(self, action: #selector(openMenu), for: .touchUpInside)
        button.layer.cornerRadius = 0
        button.layer.borderWidth = 2
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 2, height: 2)
        button.layer.shadowRadius = 0
        return button
    }()
    private var sideMenu: SideMenuViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.prefersLargeTitles = false
        delegate = self
        view.addGestureRecognizer(edgePan)
        configureFloatingMenuButton()
        updateMenuButton(for: topViewController)
        applyTheme()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFloatingMenuVisibility()
    }

    private func configureFloatingMenuButton() {
        view.addSubview(floatingMenuButton)
        NSLayoutConstraint.activate([
            floatingMenuButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(14)),
            floatingMenuButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(10)),
            floatingMenuButton.widthAnchor.constraint(equalToConstant: AppSpacing.s(44)),
            floatingMenuButton.heightAnchor.constraint(equalTo: floatingMenuButton.widthAnchor)
        ])
    }

    private func updateMenuButton(for viewController: UIViewController?) {
        guard let viewController else { return }
        viewController.navigationItem.backButtonDisplayMode = .minimal
        guard !isNavigationBarHidden else {
            updateFloatingMenuVisibility()
            return
        }

        let button = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            style: .plain,
            target: self,
            action: #selector(openMenu)
        )
        button.accessibilityLabel = "メニュー"

        let hasLeftItem = viewController.navigationItem.leftBarButtonItem != nil
        let hasLeftItems = (viewController.navigationItem.leftBarButtonItems?.isEmpty == false)
        if !hasLeftItem && !hasLeftItems {
            viewController.navigationItem.leftBarButtonItem = button
            updateFloatingMenuVisibility()
            return
        }

        if viewController.navigationItem.rightBarButtonItem == nil {
            viewController.navigationItem.rightBarButtonItem = button
        } else {
            var items = viewController.navigationItem.rightBarButtonItems ?? []
            if items.isEmpty, let rightItem = viewController.navigationItem.rightBarButtonItem {
                items = [rightItem]
            }
            if items.allSatisfy({ $0.accessibilityLabel != "メニュー" }) {
                items.append(button)
                viewController.navigationItem.rightBarButtonItems = items
            }
        }
        updateFloatingMenuVisibility()
    }

    private func updateFloatingMenuVisibility() {
        floatingMenuButton.isHidden = !isNavigationBarHidden || presentedViewController != nil
        view.bringSubviewToFront(floatingMenuButton)
    }

    private func applyTheme() {
        ThemeManager.applyNavigationAppearance(to: self)
        ThemeManager.stylePixelIconButton(floatingMenuButton)
    }

    @objc private func openMenu() {
        guard sideMenu == nil else { return }
        applyTheme()
        let menu = SideMenuViewController(items: buildMenuItems())
        menu.onDismiss = { [weak self] in
            self?.sideMenu = nil
            self?.updateFloatingMenuVisibility()
        }
        sideMenu = menu
        updateFloatingMenuVisibility()
        menu.present(in: self)
    }

    @objc private func handleEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        if recognizer.state == .recognized {
            openMenu()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer === edgePan
    }

    private func buildMenuItems() -> [SideMenuItem] {
        let palette = ThemeManager.palette()
        let currentRoute = AppRoute.route(for: visibleViewController)

        return AppRoute.allCases.map { route in
            let icon = UIImage(systemName: route.systemImageName)?
                .withTintColor(palette.text, renderingMode: .alwaysOriginal)
            return SideMenuItem(
                route: route,
                title: route.title,
                icon: icon,
                isSelected: currentRoute == route
            ) { [weak self] in
                guard let self else { return }
                AppRouter.navigate(to: route, from: self)
            }
        }
    }
}

extension MenuNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        updateMenuButton(for: viewController)
    }

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        updateMenuButton(for: viewController)
        applyTheme()
    }
}
