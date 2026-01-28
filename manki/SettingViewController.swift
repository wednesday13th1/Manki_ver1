//
//  SettingViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/25.
//

import UIKit

class SettingViewController: UIViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let themeTitleLabel = UILabel()
    private let themeStack = UIStackView()
    private var themeButtons: [UIButton] = []
    private let cardView = UIView()
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Setting"
        configureUI()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "閉じる",
            style: .plain,
            target: self,
            action: #selector(closeSelf)
        )
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }
 
    private func configureUI() {
        titleLabel.text = "THEME"
        titleLabel.textAlignment = .center
        subtitleLabel.text = "Pick your color"
        subtitleLabel.textAlignment = .center
        themeTitleLabel.text = "テーマカラー"
        themeTitleLabel.textAlignment = .left

        themeStack.axis = .horizontal
        themeStack.spacing = 12
        themeStack.alignment = .center
        themeStack.distribution = .fillEqually
        themeStack.translatesAutoresizingMaskIntoConstraints = false

        themeButtons = AppTheme.allCases.enumerated().map { index, theme in
            let button = UIButton(type: .system)
            button.tag = index
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 2
            button.addTarget(self, action: #selector(selectTheme(_:)), for: .touchUpInside)
            return button
        }
        themeButtons.forEach { themeStack.addArrangedSubview($0) }

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, cardView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        cardView.addSubview(themeTitleLabel)
        cardView.addSubview(themeStack)
        themeTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            cardView.heightAnchor.constraint(equalToConstant: 140),

            themeTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            themeTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            themeTitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            themeStack.topAnchor.constraint(equalTo: themeTitleLabel.bottomAnchor, constant: 12),
            themeStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            themeStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            themeStack.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    @objc private func selectTheme(_ sender: UIButton) {
        let themes = AppTheme.allCases
        guard sender.tag >= 0, sender.tag < themes.count else { return }
        ThemeManager.setTheme(themes[sender.tag])
        updateThemeSelection()
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        if let navigationBar = navigationController?.navigationBar {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = palette.surface
            appearance.titleTextAttributes = [
                .foregroundColor: palette.text,
                .font: AppFont.jp(size: 18, weight: .bold)
            ]
            appearance.shadowColor = palette.border
            let barAttributes: [NSAttributedString.Key: Any] = [
                .font: AppFont.jp(size: 14, weight: .bold),
                .foregroundColor: palette.text
            ]
            appearance.buttonAppearance.normal.titleTextAttributes = barAttributes
            appearance.buttonAppearance.highlighted.titleTextAttributes = barAttributes
            appearance.doneButtonAppearance.normal.titleTextAttributes = barAttributes
            appearance.doneButtonAppearance.highlighted.titleTextAttributes = barAttributes
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.tintColor = palette.text
        }

        titleLabel.font = AppFont.title(size: 18)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.en(size: 20)
        subtitleLabel.textColor = palette.mutedText
        themeTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        themeTitleLabel.textColor = palette.text

        cardView.backgroundColor = palette.surface
        cardView.layer.borderColor = palette.border.cgColor

        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            button.backgroundColor = ThemeManager.palette(for: theme).accent
        }
        updateThemeSelection()
    }

    private func updateThemeSelection() {
        let current = ThemeManager.current
        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            if theme == current {
                button.layer.borderColor = ThemeManager.palette().border.cgColor
                button.layer.shadowColor = ThemeManager.palette().border.cgColor
                button.layer.shadowOpacity = 0.25
                button.layer.shadowOffset = CGSize(width: 0, height: 2)
                button.layer.shadowRadius = 4
            } else {
                button.layer.borderColor = UIColor.clear.cgColor
                button.layer.shadowOpacity = 0
            }
        }
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
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
