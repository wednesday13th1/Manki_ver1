//
//  ExplainViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/02/02.
//

import UIKit

class ExplainViewController: UIViewController {

    private let targetLabel = UILabel()
    private let instructionLabel = UILabel()
    private let descriptionTextView = UITextView()
    private let guessButton = UIButton(type: .system)
    private let resultTitleLabel = UILabel()
    private let resultLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var guessTask: URLSessionDataTask?
    private let savedWordsFileName = "saved_words.json"
    private var targetWord: SavedWord?
    private var successOverlay: UIControl?
    private var successContainer: UIView?
    private let akinatorAttemptsKey = "AkinatorAttempts"
    private let akinatorSuccessesKey = "AkinatorSuccesses"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "アキネーター"
        view.backgroundColor = .systemBackground
        configureLayout()
        chooseRandomTarget()
    }

    private func configureLayout() {
        targetLabel.translatesAutoresizingMaskIntoConstraints = false
        targetLabel.numberOfLines = 0
        targetLabel.font = AppFont.jp(size: 16, weight: .bold)
        targetLabel.textColor = .label

        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.numberOfLines = 0
        instructionLabel.text = "単語の説明を入力してね。\nGeminiが答えを推測します。"
        instructionLabel.font = AppFont.jp(size: 14)
        instructionLabel.textColor = .secondaryLabel

        descriptionTextView.translatesAutoresizingMaskIntoConstraints = false
        descriptionTextView.font = AppFont.jp(size: 16)
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = UIColor.systemGray4.cgColor
        descriptionTextView.layer.cornerRadius = 8
        descriptionTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)

        guessButton.translatesAutoresizingMaskIntoConstraints = false
        guessButton.setTitle("答えて", for: .normal)
        guessButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        guessButton.addTarget(self, action: #selector(guessTapped), for: .touchUpInside)

        resultTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        resultTitleLabel.text = "予想:"
        resultTitleLabel.font = AppFont.jp(size: 14, weight: .bold)

        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.numberOfLines = 0
        resultLabel.text = "（まだ）"
        resultLabel.font = AppFont.jp(size: 18, weight: .bold)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            targetLabel,
            instructionLabel,
            descriptionTextView,
            guessButton,
            activityIndicator,
            resultTitleLabel,
            resultLabel
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            descriptionTextView.heightAnchor.constraint(equalToConstant: 160),
            guessButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func guessTapped() {
        view.endEditing(true)
        let input = descriptionTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            showAlert(title: "入力エラー", message: "説明を入力してください。")
            return
        }
        incrementAkinatorAttempts()
        startLoading()
        requestGuess(for: input)
    }

    private func startLoading() {
        guessButton.isEnabled = false
        activityIndicator.startAnimating()
        resultLabel.text = "推測中..."
    }

    private func stopLoading() {
        guessButton.isEnabled = true
        activityIndicator.stopAnimating()
    }

    private func requestGuess(for description: String) {
        guessTask?.cancel()
        guard let apiKey = loadGeminiAPIKey(), !apiKey.isEmpty else {
            stopLoading()
            showAlert(title: "APIキー未設定", message: "GeminiAPIKeyをInfo.plistに設定してください。")
            return
        }

        let prompt = """
        You are an Akinator-style word guesser.
        Based on the user's description, guess the single most likely English word.
        Respond with ONLY the word. No extra text.
        Description: "\(description)"
        """

        let requestBody = GeminiTextRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ]
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)") else {
            stopLoading()
            showAlert(title: "エラー", message: "API URLの作成に失敗しました。")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        guessTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if error != nil {
                DispatchQueue.main.async {
                    self.stopLoading()
                    self.showAlert(title: "通信エラー", message: "通信に失敗しました。")
                }
                return
            }

            guard let data,
                  let answer = Self.decodeAnswer(from: data) else {
                DispatchQueue.main.async {
                    self.stopLoading()
                    self.showAlert(title: "回答エラー", message: "回答を取得できませんでした。")
                }
                return
            }

            DispatchQueue.main.async {
                self.stopLoading()
                self.resultLabel.text = answer
                if self.isCorrectGuess(answer) {
                    self.incrementAkinatorSuccesses()
                    self.showSuccessModal()
                }
            }
        }
        guessTask?.resume()
    }

    private func chooseRandomTarget() {
        let words = loadSavedWords()
        guard let random = words.randomElement() else {
            targetWord = nil
            targetLabel.text = "お題: （単語がありません）"
            return
        }
        targetWord = random
        targetLabel.text = "お題: \(random.english)"
    }

    private func loadSavedWords() -> [SavedWord] {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let fileURL = documents.appendingPathComponent(savedWordsFileName)
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) else {
            return []
        }
        return decoded
    }

    private func isCorrectGuess(_ answer: String) -> Bool {
        guard let target = targetWord?.english else { return false }
        return normalizeWord(answer) == normalizeWord(target)
    }

    private func incrementAkinatorAttempts() {
        let current = UserDefaults.standard.integer(forKey: akinatorAttemptsKey)
        UserDefaults.standard.set(current + 1, forKey: akinatorAttemptsKey)
    }

    private func incrementAkinatorSuccesses() {
        let current = UserDefaults.standard.integer(forKey: akinatorSuccessesKey)
        UserDefaults.standard.set(current + 1, forKey: akinatorSuccessesKey)
    }

    private func normalizeWord(_ text: String) -> String {
        let lowered = text.lowercased()
        let filtered = lowered.filter { $0.isLetter || $0.isNumber }
        return filtered
    }

    private func loadGeminiAPIKey() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeAnswer(from data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(GeminiTextResponse.self, from: data)
        let text = decoded?.candidates?.first?.content?.parts?.first?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = text, !value.isEmpty else { return nil }
        return value.components(separatedBy: .newlines).first ?? value
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

}

private extension ExplainViewController {
    func showSuccessModal() {
        guard successOverlay == nil else { return }
        let overlay = UIControl()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.addTarget(self, action: #selector(dismissSuccessModal), for: .touchUpInside)
        overlay.accessibilityViewIsModal = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "成功！"
        titleLabel.textAlignment = .center
        titleLabel.font = AppFont.jp(size: 18, weight: .bold)

        let messageLabel = UILabel()
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "説明が伝わりました。"
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.font = AppFont.jp(size: 14)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("OK", for: .normal)
        closeButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        closeButton.addTarget(self, action: #selector(dismissSuccessModal), for: .touchUpInside)
        closeButton.layer.borderWidth = 2
        closeButton.layer.cornerRadius = 0
        closeButton.layer.masksToBounds = true

        container.addSubview(titleLabel)
        container.addSubview(messageLabel)
        container.addSubview(closeButton)
        overlay.addSubview(container)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 260),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            closeButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            closeButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
        ])

        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor
        container.layer.cornerRadius = 0
        titleLabel.textColor = palette.text
        messageLabel.textColor = palette.mutedText
        closeButton.backgroundColor = palette.surfaceAlt
        closeButton.layer.borderColor = palette.border.cgColor
        closeButton.setTitleColor(palette.text, for: .normal)

        successOverlay = overlay
        successContainer = container

        overlay.alpha = 0
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            overlay.alpha = 1
            container.alpha = 1
            container.transform = .identity
        }
    }

    @objc func dismissSuccessModal() {
        guard let overlay = successOverlay, let container = successContainer else { return }
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            overlay.alpha = 0
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { [weak self] _ in
            overlay.removeFromSuperview()
            self?.successOverlay = nil
            self?.successContainer = nil
        }
    }
}

private struct GeminiTextRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let role: String? = nil
        let parts: [Part]
    }
    let contents: [Content]
}

private struct GeminiTextResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}
