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
    private var imageTask: URLSessionDataTask?

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
        generateComicImageIfNeeded(for: SavedWord(english: english,
                                                  japanese: japanese,
                                                  illustrationScenario: scenario))
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

    private func generateComicImageIfNeeded(for word: SavedWord) {
        let url = comicFileURL(for: word)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        generateComicImage(for: word) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.saveComicImage(data, for: word)
            case .failure(let error):
                print("Comic API error: \(error.localizedDescription)")
            }
        }
    }

    private func generateComicImage(for word: SavedWord,
                                    completion: @escaping (Result<Data, ComicError>) -> Void) {
        guard let apiKey = loadComicAPIKey(), !apiKey.isEmpty else {
            completion(.failure(.missingAPIKey))
            return
        }

        guard let callbackURL = loadCallbackURL(), !callbackURL.isEmpty else {
            completion(.failure(.missingCallbackURL))
            return
        }

        guard let resultToken = loadResultToken(), !resultToken.isEmpty else {
            completion(.failure(.missingResultToken))
            return
        }

        let prompt = """
        Draw a two-panel black-and-white manga (2 panels side by side). The word is "\(word.english)" meaning "\(word.japanese)". Panel 1: setup scene. Panel 2: clear payoff that explains the meaning. No text, no speech bubbles, no letters. Simple line art, clean white background, thick outlines, easy to understand. Scenario hint: \(word.illustrationScenario ?? "none").
        """

        let requestBody = NanoBananaGenerateRequest(type: "TEXTTOIMAGE",
                                                    prompt: prompt,
                                                    numImages: 1,
                                                    imageSize: "4:3",
                                                    callBackUrl: callbackURL)

        guard let url = URL(string: "https://api.nanobananaapi.ai/api/v1/nanobanana/generate") else {
            completion(.failure(.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        imageTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.requestFailed(error.localizedDescription)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            guard let data else {
                completion(.failure(.emptyResponse))
                return
            }
            if httpResponse.statusCode != 200 {
                let message = Self.decodeNanoBananaErrorMessage(data)
                completion(.failure(.httpError(status: httpResponse.statusCode, message: message)))
                return
            }
            guard let taskId = Self.decodeNanoBananaTaskId(data) else {
                completion(.failure(.noImageData))
                return
            }
            self.pollNanoBananaResult(taskId: taskId, token: resultToken, completion: completion)
        }
        imageTask?.resume()
    }

    private func loadComicAPIKey() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "NanoBananaAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadCallbackURL() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "NanoBananaCallbackURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadResultToken() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "NanoBananaResultToken") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pollNanoBananaResult(taskId: String,
                                      token: String,
                                      completion: @escaping (Result<Data, ComicError>) -> Void) {
        let maxAttempts = 12
        let delaySeconds: TimeInterval = 2.0

        func attempt(_ count: Int) {
            guard count < maxAttempts else {
                completion(.failure(.noImageData))
                return
            }
            guard var components = URLComponents(string: "https://nanobanana-webhook.inkit98713.workers.dev/result") else {
                completion(.failure(.invalidURL))
                return
            }
            components.queryItems = [
                URLQueryItem(name: "taskId", value: taskId),
                URLQueryItem(name: "token", value: token),
            ]
            guard let url = components.url else {
                completion(.failure(.invalidURL))
                return
            }
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error {
                    completion(.failure(.requestFailed(error.localizedDescription)))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                guard let data else {
                    completion(.failure(.emptyResponse))
                    return
                }
                if httpResponse.statusCode != 200 {
                    completion(.failure(.httpError(status: httpResponse.statusCode, message: nil)))
                    return
                }
                guard let decoded = try? JSONDecoder().decode(NanoBananaResultResponse.self, from: data) else {
                    completion(.failure(.noImageData))
                    return
                }
                switch decoded.status {
                case "PENDING", "RUNNING":
                    DispatchQueue.global().asyncAfter(deadline: .now() + delaySeconds) {
                        attempt(count + 1)
                    }
                case "SUCCEEDED":
                    guard let imageUrl = decoded.results?.first?.imageUrl,
                          let downloadURL = URL(string: imageUrl) else {
                        completion(.failure(.noImageData))
                        return
                    }
                    URLSession.shared.dataTask(with: downloadURL) { imageData, _, imageError in
                        if let imageError {
                            completion(.failure(.requestFailed(imageError.localizedDescription)))
                            return
                        }
                        guard let imageData else {
                            completion(.failure(.emptyResponse))
                            return
                        }
                        completion(.success(imageData))
                    }.resume()
                default:
                    completion(.failure(.noImageData))
                }
            }.resume()
        }

        attempt(0)
    }

    private func comicFileURL(for word: SavedWord) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let safeName = sanitizeFileName(word.english)
        return documents.appendingPathComponent("comic_\(safeName).png")
    }

    private func saveComicImage(_ data: Data, for word: SavedWord) {
        let url = comicFileURL(for: word)
        try? data.write(to: url, options: .atomic)
    }

    private func sanitizeFileName(_ text: String) -> String {
        let pattern = "[^A-Za-z0-9_-]"
        return text.replacingOccurrences(of: pattern, with: "_", options: .regularExpression)
    }

    private static func decodeNanoBananaTaskId(_ data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(NanoBananaTaskResponse.self, from: data)
        return decoded?.data?.taskId
    }

    private static func decodeNanoBananaErrorMessage(_ data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(NanoBananaErrorResponse.self, from: data)
        return decoded?.message ?? decoded?.msg
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

private struct NanoBananaGenerateRequest: Encodable {
    let type: String
    let prompt: String
    let numImages: Int
    let imageSize: String
    let callBackUrl: String

    private enum CodingKeys: String, CodingKey {
        case type
        case prompt
        case numImages
        case imageSize = "image_size"
        case callBackUrl
    }
}

private struct NanoBananaTaskResponse: Decodable {
    struct DataInfo: Decodable {
        let taskId: String?
    }
    let code: Int?
    let msg: String?
    let data: DataInfo?
}

private struct NanoBananaResultResponse: Decodable {
    struct Result: Decodable {
        let imageUrl: String?
    }
    let taskId: String?
    let status: String?
    let results: [Result]?
    let error: String?
}

private struct NanoBananaErrorResponse: Decodable {
    let message: String?
    let msg: String?
}

private enum ComicError: LocalizedError {
    case missingAPIKey
    case missingCallbackURL
    case missingResultToken
    case invalidURL
    case requestFailed(String)
    case invalidResponse
    case emptyResponse
    case httpError(status: Int, message: String?)
    case noImageData

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが未設定です"
        case .missingCallbackURL:
            return "Callback URLが未設定です"
        case .missingResultToken:
            return "結果取得トークンが未設定です"
        case .invalidURL:
            return "API URLが不正です"
        case .requestFailed(let message):
            return "通信に失敗しました: \(message)"
        case .invalidResponse:
            return "不正なレスポンスです"
        case .emptyResponse:
            return "レスポンスが空でした"
        case .httpError(let status, let message):
            if let message, !message.isEmpty {
                return "APIエラー(\(status)): \(message)"
            }
            return "APIエラー(\(status))"
        case .noImageData:
            return "画像データが見つかりません"
        }
    }
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
