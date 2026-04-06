//
//  ModeViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class ModeViewController: UIViewController {

    private let backgroundImageView = UIImageView()
    private let backgroundOverlayView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let helperLabel = UILabel()
    private var themeObserver: NSObjectProtocol?
    private var isTransitioning = false

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isTransitioning = false
    }

    private func setupUI() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true

        backgroundOverlayView.translatesAutoresizingMaskIntoConstraints = false
        backgroundOverlayView.isUserInteractionEnabled = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "MANKI"
        titleLabel.textAlignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "開いたらすぐ1問。迷う前に学習開始。"
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("学習セットを開く", for: .normal)
        startButton.addTarget(self, action: #selector(openStudy), for: .touchUpInside)

        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        helperLabel.text = "設定・ステッカー・カレンダーは削除済み"
        helperLabel.numberOfLines = 0
        helperLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, startButton, helperLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = AppSpacing.s(12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(backgroundImageView)
        view.addSubview(backgroundOverlayView)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backgroundOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(24)),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            startButton.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    @objc private func openStudy() {
        guard !isTransitioning, presentedViewController == nil else { return }
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "FolderNavigationController") else {
            return
        }
        isTransitioning = true
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true) { [weak self] in
            self?.isTransitioning = false
        }
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        view.backgroundColor = palette.background
        backgroundImageView.image = backgroundImage(for: ThemeManager.current)
        backgroundImageView.alpha = 0.45
        backgroundOverlayView.backgroundColor = palette.background.withAlphaComponent(0.28)

        titleLabel.font = AppFont.title(size: 24)
        titleLabel.textColor = palette.text

        subtitleLabel.font = AppFont.jp(size: 18, weight: .bold)
        subtitleLabel.textColor = palette.text

        helperLabel.font = AppFont.jp(size: 12, weight: .bold)
        helperLabel.textColor = palette.mutedText

        startButton.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        startButton.setTitleColor(palette.text, for: .normal)
        startButton.backgroundColor = palette.accent
        startButton.layer.borderWidth = 2
        startButton.layer.borderColor = palette.border.cgColor
        startButton.layer.cornerRadius = 0
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
        return UIImage(named: baseName)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
