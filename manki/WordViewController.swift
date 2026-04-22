//
//  WordViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/17.
//

import UIKit

final class WordViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentColumn = UIStackView()
    private let introCard = UIView()
    private let introStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let listButton = UIButton(type: .system)
    private let flipButton = UIButton(type: .system)
    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?
    private var contentWidthConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "単語"
        configureUI()
        applyTheme()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLayoutMetrics()
    }

    private func configureUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        contentColumn.axis = .vertical
        contentColumn.spacing = AppLayout.sectionSpacing
        contentColumn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentColumn)

        NSLayoutConstraint.activate([
            scrollView.frameLayoutGuide.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.frameLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.frameLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.frameLayoutGuide.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentColumn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppLayout.contentVerticalInset),
            contentColumn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppLayout.contentVerticalInset),
            contentColumn.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])

        contentLeadingConstraint = contentColumn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppLayout.horizontalInset(for: view.bounds.width))
        contentTrailingConstraint = contentColumn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppLayout.horizontalInset(for: view.bounds.width))
        contentWidthConstraint = contentColumn.widthAnchor.constraint(lessThanOrEqualToConstant: AppLayout.maxContentWidth)
        NSLayoutConstraint.activate([
            contentLeadingConstraint,
            contentTrailingConstraint,
            contentWidthConstraint
        ].compactMap { $0 })

        introStack.axis = .vertical
        introStack.spacing = AppSpacing.s(10)
        introStack.translatesAutoresizingMaskIntoConstraints = false
        introCard.addSubview(introStack)

        titleLabel.text = "単語メニュー"
        subtitleLabel.text = "一覧とフリップカードの入口を、Safe Area とスクロール前提の構造で安定表示します。"
        introStack.addArrangedSubview(titleLabel)
        introStack.addArrangedSubview(subtitleLabel)

        contentColumn.addArrangedSubview(introCard)

        listButton.setTitle("一覧へ", for: .normal)
        listButton.addTarget(self, action: #selector(openList), for: .touchUpInside)
        flipButton.setTitle("フリップカードへ", for: .normal)
        flipButton.addTarget(self, action: #selector(openFlip), for: .touchUpInside)

        contentColumn.addArrangedSubview(listButton)
        contentColumn.addArrangedSubview(flipButton)

        NSLayoutConstraint.activate([
            introStack.topAnchor.constraint(equalTo: introCard.topAnchor),
            introStack.leadingAnchor.constraint(equalTo: introCard.leadingAnchor),
            introStack.trailingAnchor.constraint(equalTo: introCard.trailingAnchor),
            introStack.bottomAnchor.constraint(equalTo: introCard.bottomAnchor)
        ])
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        ThemeManager.styleCard(introCard)
        ThemeManager.stylePrimaryButton(listButton)
        ThemeManager.styleSecondaryButton(flipButton)
        titleLabel.applyMankiTextStyle(.screenTitle, color: palette.text, alignment: .center)
        subtitleLabel.applyMankiTextStyle(.body, color: palette.mutedText, alignment: .center)
    }

    private func updateLayoutMetrics() {
        let width = view.bounds.width
        let inset = AppLayout.horizontalInset(for: width)
        let cardPadding = AppLayout.cardInnerPadding(for: width)
        contentLeadingConstraint?.constant = inset
        contentTrailingConstraint?.constant = -inset
        contentWidthConstraint?.constant = min(AppLayout.maxContentWidth, width - (inset * 2))
        introStack.layoutMargins = UIEdgeInsets(top: cardPadding, left: cardPadding, bottom: cardPadding, right: cardPadding)
        introStack.isLayoutMarginsRelativeArrangement = true
    }

    @objc private func openList() {
        if let nav = navigationController,
           nav.viewControllers.first is ListTableViewController {
            nav.popToRootViewController(animated: true)
            return
        }
        guard let listVC = storyboard?.instantiateViewController(withIdentifier: "ListTableViewController") else {
            presentUnifiedModal(
                title: "遷移エラー",
                message: "一覧画面を開けませんでした。",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }
        navigationController?.pushViewController(listVC, animated: true)
    }

    @objc private func openFlip() {
        guard let flipVC = storyboard?.instantiateViewController(withIdentifier: "FlipViewController") else {
            presentUnifiedModal(
                title: "遷移エラー",
                message: "フリップ画面を開けませんでした。",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }
        navigationController?.pushViewController(flipVC, animated: true)
    }
}
