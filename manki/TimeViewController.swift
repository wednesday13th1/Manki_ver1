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

        textView.text = formatResults(flipSessions)
    }

    private func formatResults(_ sessions: [SessionResult]) -> String {
        var lines: [String] = []
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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return iso }
        let output = DateFormatter()
        output.dateFormat = "yyyy/MM/dd HH:mm"
        return output.string(from: date)
    }

    private func calculateStreakDays(_ sessions: [SessionResult]) -> Int {
        let calendar = Calendar.current
        let dates = sessions.compactMap { session -> Date? in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: session.timestamp)
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
}

private struct ResultsDatabase: Codable {
    let sessions: [SessionResult]
}
