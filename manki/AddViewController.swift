//
//  AddViewController.swift
//  manki
//
//  Created by Codex.
//

import UIKit

final class AddViewController: UIViewController {

    @IBOutlet private var englishTextField: UITextField!
    @IBOutlet private var japaneseTextField: UITextField!

    private struct AIWord: Codable {
        let word: String
        let meaning: String
    }

    private let savedWordsFileName = "saved_words.json"
    private var savedWords: [SavedWord] = []
    private var aiWords: [AIWord] = []
    private var pendingScenario: String?
    private var lastGeneratedEnglish: String?
    private var lastGeneratedJapanese: String?
    private var scenarioTask: URLSessionDataTask?

    override func viewDidLoad() {
        super.viewDidLoad()
        savedWords = loadSavedWords()
        aiWords = loadAIWordsFromBundle()
        englishTextField.addTarget(self, action: #selector(textFieldEdited), for: .editingChanged)
        japaneseTextField.addTarget(self, action: #selector(textFieldEdited), for: .editingChanged)
    }

    @objc private func textFieldEdited() {
        pendingScenario = nil
        lastGeneratedEnglish = nil
        lastGeneratedJapanese = nil
    }

    @IBAction private func saveWord() {
        let english = englishTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let japanese = japaneseTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !english.isEmpty, !japanese.isEmpty else {
            showAlert(title: "入力エラー", message: "英語と日本語を入力してください。")
            return
        }
        let scenario: String?
        if english == lastGeneratedEnglish, japanese == lastGeneratedJapanese {
            scenario = pendingScenario
        } else {
            scenario = nil
        }
        savedWords.append(SavedWord(english: english,
                                    japanese: japanese,
                                    illustrationScenario: scenario))
        saveSavedWords()
        showAlert(title: "保存しました", message: "単語を追加しました。") { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    @IBAction private func generateAIWord() {
        guard let random = aiWords.randomElement() else {
            showAlert(title: "生成エラー", message: "単語データが見つかりませんでした。")
            return
        }
        englishTextField.text = random.word
        japaneseTextField.text = random.meaning
        lastGeneratedEnglish = random.word
        lastGeneratedJapanese = random.meaning
        pendingScenario = nil
        generateIllustrationScenario(english: random.word, japanese: random.meaning)
    }

    private func savedWordsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(savedWordsFileName)
    }

    private func loadSavedWords() -> [SavedWord] {
        let fileURL = savedWordsFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            return decoded
        }
        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil) }
            savedWords = migrated
            saveSavedWords()
            return migrated
        }
        return []
    }

    private func saveSavedWords() {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(savedWords) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadAIWordsFromBundle() -> [AIWord] {
        guard let fileURL = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? JSONDecoder().decode([AIWord].self, from: data)) ?? []
    }

    private func showAlert(title: String, message: String, onOK: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            onOK?()
        })
        present(alert, animated: true)
    }

    private func generateIllustrationScenario(english: String, japanese: String) {
        scenarioTask?.cancel()
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String,
              !apiKey.isEmpty else {
            showAlert(title: "APIキー未設定", message: "GeminiAPIKeyをInfo.plistに設定してください。")
            return
        }

        let prompt = """
        日本語で「2コマ漫画のシーン指示」を作成してください。英単語: "\(english)"、意味: "\(japanese)"。
        条件:
        - 1コマ目=状況、2コマ目=意味がはっきり伝わる結末
        - 登場物は具体的に(傘、時計、ハンバーガー等)。抽象表現NG
        - 行動が分かる動詞を入れる(渡す/走る/落ちる/見つめる等)
        - セリフ・文字は入れない
        - 25語以内
        出力形式: 「1コマ目: ... / 2コマ目: ...」
        """

        let requestBody = GeminiTextRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ]
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)") else {
            showAlert(title: "生成エラー", message: "API URLが不正です。")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        scenarioTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.showAlert(title: "生成エラー", message: "通信に失敗しました: \(error.localizedDescription)")
                }
                return
            }
            guard let data else {
                DispatchQueue.main.async {
                    self.showAlert(title: "生成エラー", message: "レスポンスが空でした。")
                }
                return
            }
            if let scenario = Self.decodeScenario(from: data) {
                DispatchQueue.main.async {
                    self.pendingScenario = scenario
                }
                return
            }
            DispatchQueue.main.async {
                self.showAlert(title: "生成エラー", message: "シナリオを取得できませんでした。")
            }
        }
        scenarioTask?.resume()
    }

    private static func decodeScenario(from data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(GeminiTextResponse.self, from: data)
        let text = decoded?.candidates?.first?.content?.parts?.first?.text
        return text?.trimmingCharacters(in: .whitespacesAndNewlines)
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
