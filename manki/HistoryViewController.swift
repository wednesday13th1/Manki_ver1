//
//  HistoryViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/31.
//

import UIKit

final class HistoryViewController: UIViewController {

    private let resultsFileName = "results.json"
    private let historyCard = UIView()
    private let rangeSegmented = UISegmentedControl(items: ["1日", "1週間", "1ヶ月"])
    private let historyTitleLabel = UILabel()
    private let textView = UITextView()
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "履歴"
        configureUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadResults()
    }

    private func configureUI() {
        historyCard.translatesAutoresizingMaskIntoConstraints = false
        historyCard.layer.cornerRadius = 16
        historyCard.layer.borderWidth = 1

        historyTitleLabel.text = "フリップ履歴"
        historyTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        rangeSegmented.selectedSegmentIndex = 0
        rangeSegmented.translatesAutoresizingMaskIntoConstraints = false
        rangeSegmented.addTarget(self, action: #selector(rangeChanged), for: .valueChanged)

        textView.isEditable = false
        textView.font = AppFont.jp(size: 14)
        textView.translatesAutoresizingMaskIntoConstraints = false

        historyCard.addSubview(historyTitleLabel)
        historyCard.addSubview(textView)
        view.addSubview(rangeSegmented)
        view.addSubview(historyCard)

        NSLayoutConstraint.activate([
            rangeSegmented.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            rangeSegmented.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            historyCard.topAnchor.constraint(equalTo: rangeSegmented.bottomAnchor, constant: 12),
            historyCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            historyCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            historyCard.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            historyTitleLabel.topAnchor.constraint(equalTo: historyCard.topAnchor, constant: 12),
            historyTitleLabel.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 16),
            historyTitleLabel.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: historyTitleLabel.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: historyCard.bottomAnchor, constant: -12),
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

        let filtered = filterSessions(flipSessions)
        textView.text = formatResults(filtered)
    }

    @objc private func rangeChanged() {
        reloadResults()
    }

    private func formatResults(_ sessions: [SessionResult]) -> String {
        var lines: [String] = []
        lines.append("フリップ履歴")
        lines.append("")

        for (index, session) in sessions.enumerated() {
            let timestampText = formatTimestamp(session.timestamp)
            lines.append("#\(index + 1)  \(timestampText)")
            lines.append("  \(formatDuration(session.totalElapsedSec))")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func filterSessions(_ sessions: [SessionResult]) -> [SessionResult] {
        guard !sessions.isEmpty else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch rangeSegmented.selectedSegmentIndex {
        case 0:
            return sessions.filter { session in
                guard let date = parseISO(session.timestamp) else { return false }
                return calendar.startOfDay(for: date) == today
            }
        case 1:
            guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return sessions }
            return sessions.filter { session in
                guard let date = parseISO(session.timestamp) else { return false }
                let day = calendar.startOfDay(for: date)
                return day >= start && day <= today
            }
        default:
            guard let start = calendar.date(byAdding: .day, value: -29, to: today) else { return sessions }
            return sessions.filter { session in
                guard let date = parseISO(session.timestamp) else { return false }
                let day = calendar.startOfDay(for: date)
                return day >= start && day <= today
            }
        }
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

    private func parseISO(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)

        historyCard.backgroundColor = palette.surface
        historyCard.layer.borderColor = palette.border.cgColor

        historyTitleLabel.font = AppFont.title(size: 14)
        historyTitleLabel.textColor = palette.text

        let attrs = [NSAttributedString.Key.font: AppFont.jp(size: 12, weight: .bold)]
        rangeSegmented.setTitleTextAttributes(attrs, for: .normal)
        rangeSegmented.setTitleTextAttributes(attrs, for: .selected)
        rangeSegmented.selectedSegmentTintColor = palette.accent

        textView.backgroundColor = palette.surfaceAlt
        textView.textColor = palette.text
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = palette.border.cgColor
        textView.clipsToBounds = true
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
