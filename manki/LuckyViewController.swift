//
//  LuckyViewController.swift
//  manki
//
//  Created by Codex.
//

import UIKit

final class LuckyViewController: UIViewController {

    private let titleLabel = UILabel()
    private let omikujiCard = UIView()
    private let omikujiTitleLabel = UILabel()
    private let messageLabel = UILabel()
    private let sealLabel = UILabel()
    private let statusLabel = UILabel()
    private let drawButton = UIButton(type: .system)
    private let collectionButton = UIButton(type: .system)
    private var themeObserver: NSObjectProtocol?

    private let messages = [
        "今日の努力、ちゃんと積み上がってるよ！",
        "えらい！一歩ずつ進めば大丈夫。",
        "集中できた分、未来が軽くなる。",
        "今のがんばり、最高にかっこいい！",
        "小さな積み重ねが、大きな自信になる。",
        "よくやった！自分を褒めてOK。",
        "続けられてるのが一番すごい。",
        "今日のあなた、満点！"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "メッセージガチャ"
        configureUI()
        applyTheme()
        updateDrawState()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    private func configureUI() {
        titleLabel.text = "おみくじ"
        titleLabel.textAlignment = .center

        omikujiTitleLabel.text = "今日のひとこと"
        omikujiTitleLabel.textAlignment = .center

        messageLabel.text = "ボタンを押して引いてね"
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        sealLabel.text = "福"
        sealLabel.textAlignment = .center

        statusLabel.text = ""
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        drawButton.setTitle("引く", for: .normal)
        drawButton.addTarget(self, action: #selector(drawMessage), for: .touchUpInside)

        collectionButton.setTitle("コレクション", for: .normal)
        collectionButton.addTarget(self, action: #selector(openCollection), for: .touchUpInside)

        omikujiCard.translatesAutoresizingMaskIntoConstraints = false
        omikujiTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        sealLabel.translatesAutoresizingMaskIntoConstraints = false
        omikujiCard.addSubview(omikujiTitleLabel)
        omikujiCard.addSubview(messageLabel)
        omikujiCard.addSubview(sealLabel)

        NSLayoutConstraint.activate([
            omikujiTitleLabel.topAnchor.constraint(equalTo: omikujiCard.topAnchor, constant: 16),
            omikujiTitleLabel.leadingAnchor.constraint(equalTo: omikujiCard.leadingAnchor, constant: 16),
            omikujiTitleLabel.trailingAnchor.constraint(equalTo: omikujiCard.trailingAnchor, constant: -16),

            messageLabel.topAnchor.constraint(equalTo: omikujiTitleLabel.bottomAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: omikujiCard.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: omikujiCard.trailingAnchor, constant: -16),

            sealLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            sealLabel.centerXAnchor.constraint(equalTo: omikujiCard.centerXAnchor),
            sealLabel.widthAnchor.constraint(equalToConstant: 44),
            sealLabel.heightAnchor.constraint(equalToConstant: 44),
            sealLabel.bottomAnchor.constraint(equalTo: omikujiCard.bottomAnchor, constant: -16),
        ])

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            omikujiCard,
            statusLabel,
            drawButton,
            collectionButton
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            drawButton.heightAnchor.constraint(equalToConstant: 44),
            collectionButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        titleLabel.font = AppFont.jp(size: 18, weight: .bold)
        titleLabel.textColor = palette.text
        omikujiTitleLabel.font = AppFont.jp(size: 14, weight: .bold)
        omikujiTitleLabel.textColor = palette.mutedText
        messageLabel.font = AppFont.jp(size: 16, weight: .bold)
        messageLabel.textColor = palette.text
        statusLabel.font = AppFont.jp(size: 12, weight: .bold)
        statusLabel.textColor = palette.mutedText
        sealLabel.font = AppFont.jp(size: 18, weight: .bold)
        sealLabel.textColor = palette.surface
        sealLabel.backgroundColor = palette.accentStrong
        sealLabel.layer.cornerRadius = 22
        sealLabel.layer.masksToBounds = true

        omikujiCard.backgroundColor = palette.surface
        omikujiCard.layer.borderWidth = 2
        omikujiCard.layer.borderColor = palette.border.cgColor
        omikujiCard.layer.cornerRadius = 12

        ThemeManager.stylePrimaryButton(drawButton)
        drawButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        ThemeManager.styleSecondaryButton(collectionButton)
        collectionButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
    }

    @objc private func drawMessage() {
        guard LuckyStore.canDrawToday() else {
            updateDrawState()
            return
        }
        let message = messages.randomElement() ?? "今日もおつかれさま！"
        messageLabel.text = message
        LuckyStore.markDraw(message: message)
        updateDrawState()
    }

    private func updateDrawState() {
        let canDraw = LuckyStore.canDrawToday()
        drawButton.isEnabled = canDraw
        statusLabel.text = canDraw ? "今日の分を引けます" : "今日はもう引きました"
    }

    @objc private func openCollection() {
        let controller = LuckyCollectionViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
