//
//  MainTabBarController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class MainTabBarController: UITabBarController {
    private lazy var closeButton: UIBarButtonItem = {
        UIBarButtonItem(
            title: "戻る",
            style: .plain,
            target: self,
            action: #selector(closeSelf)
        )
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = closeButton
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
        let barAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 14, weight: .bold),
            .foregroundColor: palette.text
        ]
        closeButton.setTitleTextAttributes(barAttributes, for: .normal)
        closeButton.setTitleTextAttributes(barAttributes, for: .highlighted)
        if let navigationBar = navigationController?.navigationBar {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = palette.surface
            appearance.titleTextAttributes = [
                .foregroundColor: palette.text,
                .font: AppFont.jp(size: 18, weight: .bold)
            ]
            appearance.shadowColor = palette.border
            appearance.buttonAppearance.normal.titleTextAttributes = barAttributes
            appearance.buttonAppearance.highlighted.titleTextAttributes = barAttributes
            appearance.doneButtonAppearance.normal.titleTextAttributes = barAttributes
            appearance.doneButtonAppearance.highlighted.titleTextAttributes = barAttributes
            appearance.backButtonAppearance.normal.titleTextAttributes = barAttributes
            appearance.backButtonAppearance.highlighted.titleTextAttributes = barAttributes
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
            navigationBar.tintColor = palette.text
        }
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = palette.surface
        let tabTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 10, weight: .bold),
            .foregroundColor: palette.mutedText
        ]
        let tabSelectedAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 10, weight: .bold),
            .foregroundColor: palette.text
        ]
        [appearance.stackedLayoutAppearance,
         appearance.inlineLayoutAppearance,
         appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.titleTextAttributes = tabTitleAttributes
            itemAppearance.selected.titleTextAttributes = tabSelectedAttributes
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = palette.text
        tabBar.unselectedItemTintColor = palette.mutedText
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: ThemeManager.didChange, object: nil)
    }
}
