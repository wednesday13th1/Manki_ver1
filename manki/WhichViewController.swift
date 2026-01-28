//
//  WhichViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/28.
//

import UIKit

class WhichViewController: UIViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var themeObserver: NSObjectProtocol?

    private lazy var testButton: UIButton = makeButton(
        title: "テスト",
        action: #selector(openTest)
    )

    private lazy var flipButton: UIButton = makeButton(
        title: "フリップ",
        action: #selector(openFlip)
    )

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

    private func setupUI() {
        titleLabel.text = "Study Mode"
        titleLabel.textAlignment = .center
        subtitleLabel.text = ""
        subtitleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, testButton, flipButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7)
        ])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func openTest() {
        let controller = TestViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openFlip() {
        let controller = FlipViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        titleLabel.font = AppFont.title(size: 20)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.en(size: 22)
        subtitleLabel.textColor = palette.mutedText
        ThemeManager.stylePrimaryButton(testButton)
        ThemeManager.styleSecondaryButton(flipButton)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
