import UIKit

final class SideMenuViewController: UIViewController {
    private let menuWidth: CGFloat = 280
    private let dimmingView = UIControl()
    private let menuContainer = UIView()
    private let menuStack = UIStackView()
    private let titleLabel = UILabel()
    private var items: [SideMenuItem]
    private var themeObserver: NSObjectProtocol?

    var onDismiss: (() -> Void)?

    init(items: [SideMenuItem]) {
        self.items = items
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func configureUI() {
        view.backgroundColor = .clear

        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dimmingView.alpha = 0
        dimmingView.addTarget(self, action: #selector(handleClose), for: .touchUpInside)

        menuContainer.translatesAutoresizingMaskIntoConstraints = false
        menuContainer.layer.cornerRadius = 18
        menuContainer.layer.borderWidth = 2
        menuContainer.layer.shadowColor = UIColor.black.cgColor
        menuContainer.layer.shadowOpacity = 0.18
        menuContainer.layer.shadowOffset = CGSize(width: 2, height: 4)
        menuContainer.layer.shadowRadius = 8

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "MENU"
        titleLabel.textAlignment = .left

        menuStack.translatesAutoresizingMaskIntoConstraints = false
        menuStack.axis = .vertical
        menuStack.spacing = AppSpacing.s(10)
        menuStack.alignment = .fill

        view.addSubview(dimmingView)
        view.addSubview(menuContainer)
        menuContainer.addSubview(titleLabel)
        menuContainer.addSubview(menuStack)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            menuContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(12)),
            menuContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(12)),
            menuContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppSpacing.s(12)),
            menuContainer.widthAnchor.constraint(equalToConstant: menuWidth),

            titleLabel.topAnchor.constraint(equalTo: menuContainer.topAnchor, constant: AppSpacing.s(18)),
            titleLabel.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor, constant: AppSpacing.s(18)),
            titleLabel.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor, constant: -AppSpacing.s(18)),

            menuStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(16)),
            menuStack.leadingAnchor.constraint(equalTo: menuContainer.leadingAnchor, constant: AppSpacing.s(14)),
            menuStack.trailingAnchor.constraint(equalTo: menuContainer.trailingAnchor, constant: -AppSpacing.s(14)),
            menuStack.bottomAnchor.constraint(lessThanOrEqualTo: menuContainer.bottomAnchor, constant: -AppSpacing.s(18))
        ])

        updateMenuItems()
    }

    private func updateMenuItems() {
        menuStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.enumerated().forEach { index, item in
            let button = UIButton(type: .system)
            button.tag = index
            button.contentHorizontalAlignment = .left
            button.contentEdgeInsets = UIEdgeInsets(top: AppSpacing.s(10),
                                                   left: AppSpacing.s(12),
                                                   bottom: AppSpacing.s(10),
                                                   right: AppSpacing.s(12))
            button.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: AppSpacing.s(8), bottom: 0, right: 0)
            button.setTitle(item.title, for: .normal)
            button.tintColor = ThemeManager.palette().text
            if let icon = item.icon {
                button.setImage(icon, for: .normal)
            }
            button.layer.cornerRadius = 14
            button.layer.borderWidth = 1
            button.addTarget(self, action: #selector(handleItemTap(_:)), for: .touchUpInside)
            menuStack.addArrangedSubview(button)

            let height = button.heightAnchor.constraint(equalToConstant: AppSpacing.s(52))
            height.priority = .required
            height.isActive = true
        }
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        menuContainer.backgroundColor = palette.surface
        menuContainer.layer.borderColor = palette.border.cgColor
        titleLabel.textColor = palette.text
        titleLabel.font = AppFont.en(size: 20, weight: .regular)

        menuStack.arrangedSubviews.forEach { view in
            guard let button = view as? UIButton else { return }
            button.setTitleColor(palette.text, for: .normal)
            button.backgroundColor = palette.surfaceAlt
            button.layer.borderColor = palette.border.cgColor
        }
    }

    func present(in parent: UIViewController) {
        parent.present(self, animated: false) { [weak self] in
            self?.animateIn()
        }
    }

    private func animateIn() {
        menuContainer.transform = CGAffineTransform(translationX: -menuWidth, y: 0)
        dimmingView.alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.dimmingView.alpha = 1
            self.menuContainer.transform = .identity
        }
    }

    private func animateOut(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
            self.dimmingView.alpha = 0
            self.menuContainer.transform = CGAffineTransform(translationX: -self.menuWidth, y: 0)
        } completion: { _ in
            completion?()
        }
    }

    @objc private func handleClose() {
        animateOut { [weak self] in
            self?.dismiss(animated: false) {
                self?.onDismiss?()
            }
        }
    }

    @objc private func handleItemTap(_ sender: UIButton) {
        guard sender.tag >= 0, sender.tag < items.count else { return }
        let action = items[sender.tag].action
        animateOut { [weak self] in
            self?.dismiss(animated: false) {
                action()
            }
        }
    }
}
