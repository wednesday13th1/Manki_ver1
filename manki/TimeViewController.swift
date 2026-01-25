//
//  TimeViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class TimeViewController: UIViewController {

    private let resultsFileName = "results.json"
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "勉強時間"
        view.backgroundColor = .systemBackground

        configureUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadResults()
        checkDailyGoalAchievement()
    }

    private func configureUI() {
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 14)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private func resultsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(resultsFileName)
    }

    private func reloadResults() {
        let url = resultsFileURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ResultsDatabase.self, from: data) else {
            textView.text = "フリップ履歴がありません。"
            return
        }

        let flipSessions = decoded.sessions.filter { session in
            session.reason == "flip" || session.modeLabel == "フリップ"
        }

        if flipSessions.isEmpty {
            textView.text = "フリップ履歴がありません。"
            return
        }

        textView.text = formatResults(flipSessions, allSessions: decoded.sessions)
    }

    private func checkDailyGoalAchievement() {
        guard let goalMinutes = DailyGoalStore.goalMinutesForToday(),
              DailyGoalStore.shouldShowAchievedAlert() else {
            return
        }
        let todayTotal = todayFlipSeconds()
        if todayTotal >= Double(goalMinutes * 60) {
            DailyGoalStore.markAchievedAlertShown()
            let message = "目標 \(goalMinutes)分を達成しました！"
            showAlert(title: "達成おめでとう！", message: message)
        }
    }

    private func todayFlipSeconds() -> Double {
        let url = resultsFileURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ResultsDatabase.self, from: data) else {
            return 0
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sessions = decoded.sessions.filter { session in
            session.reason == "flip" || session.modeLabel == "フリップ"
        }
        let total = sessions.reduce(0.0) { partial, session in
            guard let date = parseISO(session.timestamp) else { return partial }
            let day = calendar.startOfDay(for: date)
            if day == today {
                return partial + session.totalElapsedSec
            }
            return partial
        }
        return total
    }

    private func formatResults(_ sessions: [SessionResult], allSessions: [SessionResult]) -> String {
        var lines: [String] = []
        let learnedCount = learnedWordCount(from: allSessions)
        lines.append("学習した単語数: \(learnedCount)")
        let totalSeconds = sessions.reduce(0) { $0 + $1.totalElapsedSec }
        lines.append("フリップ総合時間: \(formatDuration(totalSeconds))")
        lines.append("連続日数: \(calculateStreakDays(sessions))日")
        lines.append("")
        lines.append("=== フリップ履歴 ===")

        for (index, session) in sessions.enumerated() {
            let timestampText = formatTimestamp(session.timestamp)
            lines.append("履歴 \(index + 1)")
            lines.append("  日時: \(timestampText)")
            lines.append("  勉強時間: \(formatDuration(session.totalElapsedSec))")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分\(secs)秒"
        }
        if minutes > 0 {
            return "\(minutes)分\(secs)秒"
        }
        return "\(secs)秒"
    }

    private func formatTimestamp(_ iso: String) -> String {
        guard let date = parseISO(iso) else { return iso }
        let output = DateFormatter()
        output.dateFormat = "yyyy/MM/dd HH:mm"
        return output.string(from: date)
    }

    private func calculateStreakDays(_ sessions: [SessionResult]) -> Int {
        let calendar = Calendar.current
        let dates = sessions.compactMap { session -> Date? in
            return parseISO(session.timestamp)
        }
        let daySet = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !daySet.isEmpty else { return 0 }

        var streak = 0
        var current = calendar.startOfDay(for: Date())
        while daySet.contains(current) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: current) else { break }
            current = prev
        }
        return streak
    }

    private func learnedWordCount(from sessions: [SessionResult]) -> Int {
        var keys = Set<String>()
        for session in sessions {
            for question in session.questions {
                if let wordId = question.wordId, !wordId.isEmpty {
                    keys.insert("id:\(wordId)")
                    continue
                }
                let prompt = normalizeKey(question.prompt)
                let answer = normalizeKey(question.correctAnswer)
                if !prompt.isEmpty || !answer.isEmpty {
                    keys.insert("pair:\(prompt)|\(answer)")
                }
            }
        }
        return keys.count
    }

    private func normalizeKey(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func parseISO(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
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

    enum CodingKeys: String, CodingKey {
        case timestamp
        case reason
        case modeLabel
        case directionLabel
        case totalQuestionsGenerated
        case answered
        case score
        case accuracy
        case totalElapsedSec
        case questions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        reason = try container.decode(String.self, forKey: .reason)
        modeLabel = try container.decodeIfPresent(String.self, forKey: .modeLabel)
        directionLabel = try container.decodeIfPresent(String.self, forKey: .directionLabel)
        totalQuestionsGenerated = try container.decodeIfPresent(Int.self, forKey: .totalQuestionsGenerated) ?? 0
        answered = try container.decodeIfPresent(Int.self, forKey: .answered) ?? 0
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        accuracy = try container.decodeIfPresent(Double.self, forKey: .accuracy) ?? 0
        totalElapsedSec = try container.decodeIfPresent(Double.self, forKey: .totalElapsedSec) ?? 0
        questions = try container.decodeIfPresent([SessionQuestion].self, forKey: .questions) ?? []
    }
}

private struct ResultsDatabase: Codable {
    let sessions: [SessionResult]
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
