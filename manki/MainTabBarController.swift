//
//  MainTabBarController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "戻る",
            style: .plain,
            target: self,
            action: #selector(closeSelf)
        )
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: ThemeManager.didChange,
            object: nil
        )
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
    }

    @objc private func handleThemeChange() {
        applyTheme()
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyNavigationAppearance(to: navigationController)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = palette.surface
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = palette.text
        tabBar.unselectedItemTintColor = palette.mutedText
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: ThemeManager.didChange, object: nil)
    }
}
