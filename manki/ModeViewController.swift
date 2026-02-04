//
//  ModeViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

class ModeViewController: UIViewController {

    private let backgroundImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    private lazy var folderButton: UIButton = makeButton(
        title: "フォルダへ",
        action: #selector(goToFolder)
    )

    private lazy var tabBarButton: UIButton = makeButton(
        title: "スケジュール/履歴へ",
        action: #selector(goToTabBar)
    )

    private lazy var settingButton: UIButton = makeButton(
        title: "設定",
        action: #selector(goToSetting)
    )

    private lazy var goalButton: UIButton = makeButton(
        title: "目標設定",
        action: #selector(goToGoal)
    )

    private lazy var stickerButton: UIButton = makeButton(
        title: "ステッカーへ",
        action: #selector(goToSticker)
    )

    private lazy var collabButton: UIButton = makeButton(
        title: "コラボ",
        action: #selector(goToCollab)
    )

    private func setupUI() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.alpha = 0.8

        titleLabel.text = "MANKI"
        titleLabel.textAlignment = .center
        subtitleLabel.text = "Study Mode"
        subtitleLabel.textAlignment = .center

        view.addSubview(backgroundImageView)
        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            folderButton,
            tabBarButton,
            goalButton,
            stickerButton,
            collabButton,
            settingButton
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        let centerY = stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        centerY.priority = .defaultLow
        NSLayoutConstraint.activate([
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerY,
            stack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7)
        ])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        let preferredHeight = button.heightAnchor.constraint(equalToConstant: 48)
        preferredHeight.priority = .defaultHigh
        preferredHeight.isActive = true
        let minHeight = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        minHeight.priority = .defaultLow
        minHeight.isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func goToFolder() {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "FolderNavigationController") else {
            return
        }
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func goToTabBar() {
        guard let tabBar = storyboard?.instantiateViewController(withIdentifier: "MainTabBarController") else {
            return
        }
        let nav = UINavigationController(rootViewController: tabBar)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func goToSetting() {
        let controller = SettingViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func goToSticker() {
        let controller = StiCamViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func goToCollab() {
        let controller = TurnCollabViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func goToGoal() {
        let controller = GoalViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        view.backgroundColor = palette.background
        backgroundImageView.image = backgroundImage(for: ThemeManager.current)
        titleLabel.font = AppFont.title(size: 20)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.en(size: 22)
        subtitleLabel.textColor = palette.mutedText
        ThemeManager.stylePrimaryButton(folderButton)
        ThemeManager.stylePrimaryButton(tabBarButton)
        ThemeManager.stylePrimaryButton(goalButton)
        ThemeManager.stylePrimaryButton(stickerButton)
        ThemeManager.stylePrimaryButton(collabButton)
        ThemeManager.styleSecondaryButton(settingButton)
    }

    private func backgroundImage(for theme: AppTheme) -> UIImage? {
        let baseName: String
        switch theme {
        case .pink:
            baseName = "pnk"
        case .purple:
            baseName = "prpl"
        case .green:
            baseName = "grrn"
        case .yellow:
            baseName = "yllw"
        case .blue:
            baseName = "bleu"
        }
        if let image = UIImage(named: baseName) {
            return image
        }
        let extensions = ["png", "jpg", "jpeg"]
        for ext in extensions {
            if let path = Bundle.main.path(forResource: baseName, ofType: ext),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
