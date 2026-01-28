//
//  ResultViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/15.
//

import UIKit

final class ResultViewController: UIViewController {

    private let resultsFileName = "results.json"
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "結果"
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
            textView.text = "まだ結果がありません。"
            return
        }

        if decoded.sessions.isEmpty {
            textView.text = "まだ結果がありません。"
            return
        }

        textView.text = formatResults(decoded.sessions)
    }

    private func formatResults(_ sessions: [SessionResult]) -> String {
        var lines: [String] = []
        for (index, session) in sessions.enumerated() {
            lines.append("=== Session \(index + 1) ===")
            lines.append("timestamp: \(session.timestamp)")
            lines.append("reason: \(session.reason)")
            let modeLabel = session.modeLabel ?? "不明"
            let directionLabel = session.directionLabel ?? "不明"
            lines.append("mode: \(modeLabel) / \(directionLabel)")
            lines.append("score: \(session.score)/\(session.answered)")
            lines.append(String(format: "正答率: %.1f%%", session.accuracy * 100))
            lines.append(String(format: "合計時間: %.2fs", session.totalElapsedSec))
            lines.append("questions:")
            for question in session.questions {
                let result = question.correct ? "correct" : "wrong"
                lines.append("  Q\(question.index) [\(question.type), \(question.direction)]")
                lines.append("    prompt: \(question.prompt)")
                lines.append("    answer: \(question.userAnswer) (\(result))")
                lines.append("    correct: \(question.correctAnswer)")
                lines.append(String(format: "    time: %.2fs", question.answerTimeSec))
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

private struct SessionQuestion: Codable {
    let index: Int
    let type: String
    let direction: String
    let prompt: String
    let correctAnswer: String
    let userAnswer: String
    let correct: Bool
    let answerTimeSec: Double
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

private struct ResultsDatabase: Codable {
    let sessions: [SessionResult]
}
