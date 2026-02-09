//
//  WordViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/17.
//

import UIKit

class WordViewController: UIViewController {

    private let stackView = UIStackView()
    private let listButton = UIButton(type: .system)
    private let flipButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "単語"
        view.backgroundColor = .systemBackground
        configureUI()
    }

    private func configureUI() {
        stackView.axis = .vertical
        stackView.spacing = AppSpacing.s(16)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24)),
        ])

        listButton.setTitle("一覧へ", for: .normal)
        listButton.addTarget(self, action: #selector(openList), for: .touchUpInside)
        stackView.addArrangedSubview(listButton)

        flipButton.setTitle("フリップカードへ", for: .normal)
        flipButton.addTarget(self, action: #selector(openFlip), for: .touchUpInside)
        stackView.addArrangedSubview(flipButton)
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
