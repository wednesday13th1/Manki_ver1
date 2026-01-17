//
//  QuizViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/15.
//

import UIKit

final class QuizViewController: UIViewController {

    private let contentStack = UIStackView()
    private let startTestButton = UIButton(type: .system)
    private let resultsButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "クイズ"
        view.backgroundColor = .systemBackground

        configureUI()
    }

    private func configureUI() {
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "クイズメニュー"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.textAlignment = .center
        contentStack.addArrangedSubview(titleLabel)

        startTestButton.setTitle("テスト開始", for: .normal)
        startTestButton.addTarget(self, action: #selector(openTest), for: .touchUpInside)
        contentStack.addArrangedSubview(startTestButton)

        resultsButton.setTitle("結果を見る", for: .normal)
        resultsButton.addTarget(self, action: #selector(openResults), for: .touchUpInside)
        contentStack.addArrangedSubview(resultsButton)
    }

    @objc private func openTest() {
        let controller = TestViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openResults() {
        let controller = ResultViewController()
        navigationController?.pushViewController(controller, animated: true)
    }
}
