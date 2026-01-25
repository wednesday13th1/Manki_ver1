//
//  DailyGoalViewController.swift
//  manki
//
//  Created by Codex.
//

import UIKit

final class DailyGoalViewController: UIViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let minutesField = UITextField()
    private let saveButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureUI()
    }

    private func configureUI() {
        titleLabel.text = "今日の勉強時間目標"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.textAlignment = .center

        subtitleLabel.text = "分数を入力してください"
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        minutesField.borderStyle = .roundedRect
        minutesField.placeholder = "例: 30"
        minutesField.keyboardType = .numberPad
        minutesField.textAlignment = .center

        saveButton.setTitle("設定する", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.addTarget(self, action: #selector(saveGoal), for: .touchUpInside)

        skipButton.setTitle("スキップ", for: .normal)
        skipButton.addTarget(self, action: #selector(skipGoal), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, minutesField, saveButton, skipButton
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        minutesField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        saveButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        skipButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    @objc private func saveGoal() {
        let text = minutesField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let minutes = Int(text) ?? 0
        DailyGoalStore.setGoal(minutes: minutes)
        dismiss(animated: true)
    }

    @objc private func skipGoal() {
        dismiss(animated: true)
    }
}
