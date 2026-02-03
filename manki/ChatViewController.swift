//
//  ChatViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/02/02.
//

import UIKit

class ChatViewController: UIViewController {

    private struct ChatMessage {
        let role: String
        let text: String
    }

    private let tableView = UITableView()
    private let inputContainer = UIView()
    private let inputTextView = UITextView()
    private let sendButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var inputBottomConstraint: NSLayoutConstraint?
    private var messages: [ChatMessage] = []
    private var chatTask: URLSessionDataTask?
    private let resultsFileName = "results.json"
    private let akinatorAttemptsKey = "AkinatorAttempts"
    private let akinatorSuccessesKey = "AkinatorSuccesses"
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Study Chat"
        view.backgroundColor = .systemBackground
        configureNavigation()
        configureLayout()
        applyTheme()
        registerForKeyboard()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
            self?.tableView.reloadData()
        }
    }

    private func configureNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "戻る",
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        ThemeManager.applyNavigationAppearance(to: navigationController)
    }

    private func configureLayout() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        view.addSubview(tableView)

        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.layer.borderWidth = 2
        inputContainer.layer.cornerRadius = 0
        view.addSubview(inputContainer)

        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.font = AppFont.jp(size: 15)
        inputTextView.layer.cornerRadius = 0
        inputTextView.layer.borderWidth = 2
        inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        inputContainer.addSubview(inputTextView)

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("送信", for: .normal)
        sendButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        inputContainer.addSubview(sendButton)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        inputContainer.addSubview(activityIndicator)

        inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),

            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBottomConstraint!,

            inputTextView.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputTextView.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            inputTextView.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            inputTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),

            sendButton.leadingAnchor.constraint(equalTo: inputTextView.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputTextView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),

            activityIndicator.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            activityIndicator.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
        ])
    }

    @objc private func sendTapped() {
        let text = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputTextView.text = ""
        appendMessage(role: "user", text: text)
        requestChatResponse(for: text)
    }

    private func appendMessage(role: String, text: String) {
        messages.append(ChatMessage(role: role, text: text))
        tableView.reloadData()
        if !messages.isEmpty {
            let indexPath = IndexPath(row: messages.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }

    private func requestChatResponse(for userText: String) {
        chatTask?.cancel()
        guard let apiKey = loadGeminiChatAPIKey(), !apiKey.isEmpty else {
            appendMessage(role: "model", text: "GeminiChatAPIKeyが設定されていません。")
            return
        }

        activityIndicator.startAnimating()
        sendButton.isEnabled = false

        let stats = buildStatsSummary()
        let systemPrompt = """
        You are a study coach inside a learning app.
        Provide friendly, concrete advice in Japanese.
        Use the app stats below.
        반드시「週間プラン」を含め、アプリ内モードごとの時間配分を具体的に提案すること。
        Output should be concise and structured.
        """

        var contents: [GeminiTextRequest.Content] = [
            .init(role: "user", parts: [.init(text: systemPrompt)]),
            .init(role: "user", parts: [.init(text: stats)])
        ]
        contents.append(contentsOf: messages.map { message in
            GeminiTextRequest.Content(role: message.role, parts: [.init(text: message.text)])
        })

        let requestBody = GeminiTextRequest(contents: contents)

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)") else {
            appendMessage(role: "model", text: "API URLの作成に失敗しました。")
            activityIndicator.stopAnimating()
            sendButton.isEnabled = true
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        chatTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.sendButton.isEnabled = true
            }

            if error != nil {
                DispatchQueue.main.async {
                    self.appendMessage(role: "model", text: "通信に失敗しました。")
                }
                if let error {
                    print("Gemini chat error: \(error.localizedDescription)")
                }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if let data, statusCode >= 400 {
                let preview = String(data: data.prefix(800), encoding: .utf8) ?? "<empty>"
                print("Gemini chat status: \(statusCode)")
                print("Gemini chat body preview: \(preview)")
                let message = Self.decodeGeminiErrorMessage(from: data) ?? "APIエラーが発生しました。"
                DispatchQueue.main.async {
                    self.appendMessage(role: "model", text: message)
                }
                return
            }

            guard let data,
                  let reply = Self.decodeAnswer(from: data) else {
                DispatchQueue.main.async {
                    self.appendMessage(role: "model", text: "回答を取得できませんでした。")
                }
                return
            }

            DispatchQueue.main.async {
                self.appendMessage(role: "model", text: reply)
            }
        }
        chatTask?.resume()
    }

    private func buildStatsSummary() -> String {
        let stats = loadStudyStats()
        let akinator = loadAkinatorStats()
        let totalFlip = formatDuration(stats.totalFlipSeconds)
        let weekFlip = formatDuration(stats.last7DaysFlipSeconds)
        let testAccuracy = stats.testAccuracy == nil ? "-" : String(format: "%.1f%%", (stats.testAccuracy ?? 0) * 100)
        let akinatorAccuracy = akinator.attempts == 0 ? "-" : String(format: "%.1f%%", Double(akinator.successes) / Double(akinator.attempts) * 100)

        return """
        App stats:
        - 勉強時間(フリップ合計): \(totalFlip)
        - 勉強時間(直近7日): \(weekFlip)
        - テスト正答率(平均): \(testAccuracy)
        - アキネーター正答率: \(akinatorAccuracy) (成功 \(akinator.successes) / 試行 \(akinator.attempts))
        """
    }

    private func loadStudyStats() -> (totalFlipSeconds: Double, last7DaysFlipSeconds: Double, testAccuracy: Double?) {
        let db = loadResults()
        let flipSessions = db.sessions.filter { session in
            session.reason == "flip" || session.modeLabel == "フリップ"
        }
        let totalFlipSeconds = flipSessions.reduce(0) { $0 + $1.totalElapsedSec }

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let last7DaysFlipSeconds = flipSessions.reduce(0) { partial, session in
            guard let date = parseISO(session.timestamp), date >= start else { return partial }
            return partial + session.totalElapsedSec
        }

        let testSessions = db.sessions.filter { session in
            session.reason != "flip" && session.modeLabel != "フリップ" && session.answered > 0
        }
        let testAccuracy: Double?
        if testSessions.isEmpty {
            testAccuracy = nil
        } else {
            testAccuracy = testSessions.reduce(0) { $0 + $1.accuracy } / Double(testSessions.count)
        }

        return (totalFlipSeconds, last7DaysFlipSeconds, testAccuracy)
    }

    private func loadAkinatorStats() -> (attempts: Int, successes: Int) {
        let attempts = UserDefaults.standard.integer(forKey: akinatorAttemptsKey)
        let successes = UserDefaults.standard.integer(forKey: akinatorSuccessesKey)
        return (attempts, successes)
    }

    private func loadResults() -> ResultsDatabase {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let url = documents.appendingPathComponent(resultsFileName)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ResultsDatabase.self, from: data) else {
            return ResultsDatabase(sessions: [])
        }
        return decoded
    }

    private func parseISO(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }

    private func loadGeminiChatAPIKey() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "GeminiChatAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeAnswer(from data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(GeminiTextResponse.self, from: data)
        let text = decoded?.candidates?.first?.content?.parts?.first?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = text, !value.isEmpty else { return nil }
        return value
    }

    private static func decodeGeminiErrorMessage(from data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data)
        return decoded?.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func registerForKeyboard() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleKeyboardWillChange),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }

    @objc private func handleKeyboardWillChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let frameValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }

        let frame = frameValue.cgRectValue
        let keyboardHeight = max(0, view.bounds.height - frame.origin.y)
        inputBottomConstraint?.constant = -keyboardHeight
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        tableView.backgroundColor = .clear
        inputContainer.backgroundColor = palette.surface
        inputContainer.layer.borderColor = palette.border.cgColor
        inputTextView.backgroundColor = palette.surfaceAlt
        inputTextView.textColor = palette.text
        inputTextView.layer.borderColor = palette.border.cgColor
        ThemeManager.stylePrimaryButton(sendButton)
        ThemeManager.applyNavigationAppearance(to: navigationController)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

}

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ??
            UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let message = messages[indexPath.row]
        let palette = ThemeManager.palette()
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = AppFont.jp(size: 15)
        cell.textLabel?.text = message.text
        if message.role == "user" {
            cell.textLabel?.textAlignment = .right
            cell.contentView.backgroundColor = palette.surfaceAlt
        } else {
            cell.textLabel?.textAlignment = .left
            cell.contentView.backgroundColor = palette.surface
        }
        cell.contentView.layer.borderWidth = 2
        cell.contentView.layer.borderColor = palette.border.cgColor
        cell.contentView.layer.cornerRadius = 0
        cell.textLabel?.textColor = palette.text
        cell.textLabel?.backgroundColor = .clear
        return cell
    }
}

private struct GeminiTextRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let role: String?
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

private struct GeminiErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String?
    }
    let error: APIError?
}

private struct ResultsDatabase: Codable {
    let sessions: [SessionResult]
}

private struct SessionResult: Codable {
    let timestamp: String
    let reason: String
    let modeLabel: String?
    let directionLabel: String?
    let totalQuestionsGenerated: Int
    let answered: Int
    let score: Int
    let accuracy: Double
    let totalElapsedSec: Double
    let questions: [SessionQuestion]
}

private struct SessionQuestion: Codable {
    let index: Int
    let type: String
    let direction: String
    let wordId: String?
    let prompt: String
    let correctAnswer: String
    let userAnswer: String
    let correct: Bool
    let answerTimeSec: Double
}
