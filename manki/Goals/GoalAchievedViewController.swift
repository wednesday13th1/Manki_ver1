//
//  GoalAchievedViewController.swift
//  manki
//
//  Created by Codex.
//

import UIKit

final class GoalAchievedViewController: UIViewController {

    private let overlay = UIControl()
    private let container = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    private let minutes: Int

    init(minutes: Int) {
        self.minutes = minutes
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        applyTheme()
    }

    private func configureUI() {
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.addTarget(self, action: #selector(closeSelf), for: .touchUpInside)

        container.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "達成おめでとう！"
        titleLabel.textAlignment = .center

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "目標 \(minutes)分を達成しました！"
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("OK", for: .normal)
        closeButton.addTarget(self, action: #selector(closeSelf), for: .touchUpInside)

        view.addSubview(overlay)
        overlay.addSubview(container)
        container.addSubview(titleLabel)
        container.addSubview(messageLabel)
        container.addSubview(closeButton)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: AppSpacing.s(24)),
            container.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -AppSpacing.s(24)),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: 320),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: AppSpacing.s(20)),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(20)),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(20)),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(10)),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(20)),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(20)),

            closeButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: AppSpacing.s(16)),
            closeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(24)),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(24)),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AppSpacing.s(20)),
        ])
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor
        container.layer.cornerRadius = 12

        titleLabel.font = AppFont.jp(size: 18, weight: .bold)
        titleLabel.textColor = palette.text
        messageLabel.font = AppFont.jp(size: 14, weight: .bold)
        messageLabel.textColor = palette.text

        ThemeManager.stylePrimaryButton(closeButton)
        closeButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
    }
}
