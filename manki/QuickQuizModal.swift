//
//  QuickQuizModal.swift
//  manki
//
//  Created by Codex.
//

import UIKit

enum LastStudyStore {
    private static let setIDKey = "manki.last_studied_set_id"
    private static let setNameKey = "manki.last_studied_set_name"

    static func save(setID: String, setName: String) {
        UserDefaults.standard.set(setID, forKey: setIDKey)
        UserDefaults.standard.set(setName, forKey: setNameKey)
    }

    static func load() -> (id: String, name: String)? {
        guard let id = UserDefaults.standard.string(forKey: setIDKey) else { return nil }
        let name = UserDefaults.standard.string(forKey: setNameKey) ?? "セット"
        return (id, name)
    }
}

struct QuickQuizData {
    let setName: String
    let prompt: String
    let choices: [String]
    let correct: String
}

enum QuickQuizFactory {
    static func makeQuestion() -> QuickQuizData? {
        guard let last = LastStudyStore.load() else { return nil }
        let sets = SetStore.loadSets()
        guard let targetSet = sets.first(where: { $0.id == last.id }) else { return nil }
        let wordsByID = Dictionary(uniqueKeysWithValues: loadSavedWords().map { ($0.id, $0) })
        let setWords = targetSet.wordIDs.compactMap { wordsByID[$0] }
        guard setWords.count >= 2 else { return nil }

        let word = setWords.randomElement()!
        let correct = word.japanese
        var pool = setWords.filter { $0.id != word.id }.map { $0.japanese }.shuffled()
        var choices = [correct]
        let limit = min(4, setWords.count)
        while choices.count < limit && !pool.isEmpty {
            let candidate = pool.removeFirst()
            if !choices.contains(candidate) {
                choices.append(candidate)
            }
        }
        choices.shuffle()

        let prompt = "「\(word.english)」の意味は？"
        return QuickQuizData(setName: last.name, prompt: prompt, choices: choices, correct: correct)
    }

    private static func loadSavedWords() -> [SavedWord] {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documents.appendingPathComponent("saved_words.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            return decoded
        }
        return []
    }
}

final class QuickQuizModal {
    private let data: QuickQuizData
    private let overlay = UIControl()
    private let container = UIView()
    private let titleLabel = UILabel()
    private let questionLabel = UILabel()
    private let resultLabel = UILabel()
    private let stack = UIStackView()
    private var choiceButtons: [UIButton] = []
    private let cancelButton = UIButton(type: .system)
    var onDismiss: (() -> Void)?

    init(data: QuickQuizData) {
        self.data = data
        buildUI()
    }

    func show(in view: UIView) {
        if overlay.superview == nil {
            view.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: view.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                container.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -AppSpacing.s(20)),
                container.widthAnchor.constraint(equalToConstant: 260),
                container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
                container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24)),
            ])
        }
        overlay.alpha = 0
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.overlay.alpha = 1
            self.container.alpha = 1
            self.container.transform = .identity
        }
    }

    private func buildUI() {
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        overlay.accessibilityViewIsModal = true

        container.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "単語"
        titleLabel.textAlignment = .center

        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        questionLabel.numberOfLines = 0
        questionLabel.textAlignment = .center
        questionLabel.text = "\(data.setName)\n\(data.prompt)"

        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.numberOfLines = 0
        resultLabel.textAlignment = .center
        resultLabel.isHidden = true

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = AppSpacing.s(8)

        data.choices.forEach { choice in
            let button = makeChoiceButton(title: choice)
            button.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            choiceButtons.append(button)
        }

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("キャンセル", for: .normal)
        cancelButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        cancelButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stack.addArrangedSubview(cancelButton)

        container.addSubview(titleLabel)
        container.addSubview(questionLabel)
        container.addSubview(resultLabel)
        container.addSubview(stack)
        overlay.addSubview(container)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: AppSpacing.s(16)),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),

            questionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(10)),
            questionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            questionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),

            resultLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: AppSpacing.s(6)),
            resultLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            resultLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),

            stack.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: AppSpacing.s(10)),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AppSpacing.s(16)),
        ])

        applyTheme()
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor

        titleLabel.font = AppFont.jp(size: 18, weight: .bold)
        titleLabel.textColor = palette.text
        questionLabel.font = AppFont.jp(size: 14, weight: .bold)
        questionLabel.textColor = palette.text
        resultLabel.font = AppFont.jp(size: 14, weight: .bold)
        resultLabel.textColor = palette.text

        (choiceButtons + [cancelButton]).forEach { button in
            button.backgroundColor = palette.surfaceAlt
            button.setTitleColor(palette.text, for: .normal)
            button.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
            button.layer.borderWidth = 2
            button.layer.borderColor = palette.border.cgColor
            button.layer.cornerRadius = 0
            button.layer.masksToBounds = true
        }
    }

    private func makeChoiceButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        return button
    }

    @objc private func choiceTapped(_ sender: UIButton) {
        guard let text = sender.title(for: .normal) else { return }
        let correct = text == data.correct
        resultLabel.text = correct ? "正解！" : "不正解… 正解: \(data.correct)"
        resultLabel.isHidden = false
        choiceButtons.forEach { $0.isEnabled = false }
        cancelButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.dismiss()
        }
    }

    @objc private func dismiss() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            self.overlay.alpha = 0
            self.container.alpha = 0
            self.container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            self.overlay.removeFromSuperview()
            self.onDismiss?()
        }
    }
}
