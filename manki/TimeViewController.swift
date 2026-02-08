//
//  TimeViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class TimeViewController: UIViewController {

    private let resultsFileName = "results.json"
    private let summaryCard = UIView()
    private let rangeSegmented = UISegmentedControl(items: ["1日", "1週間", "1ヶ月"])
    private let summaryTitleLabel = UILabel()
    private let totalTitleLabel = UILabel()
    private let streakTitleLabel = UILabel()
    private let wordsTitleLabel = UILabel()
    private let totalValueLabel = UILabel()
    private let streakValueLabel = UILabel()
    private let wordsValueLabel = UILabel()
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "勉強時間"

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
        applyTheme()
        reloadResults()
        checkDailyGoalAchievement()
    }

    private func configureUI() {
        summaryCard.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.layer.cornerRadius = 16
        summaryCard.layer.borderWidth = 1

        summaryTitleLabel.text = "勉強時間"
        summaryTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        rangeSegmented.selectedSegmentIndex = 0
        rangeSegmented.translatesAutoresizingMaskIntoConstraints = false
        rangeSegmented.addTarget(self, action: #selector(rangeChanged), for: .valueChanged)

        let totalStack = makeStatStack(titleLabel: totalTitleLabel, valueLabel: totalValueLabel, title: "合計時間")
        let streakStack = makeStatStack(titleLabel: streakTitleLabel, valueLabel: streakValueLabel, title: "勉強日数")
        let wordsStack = makeStatStack(titleLabel: wordsTitleLabel, valueLabel: wordsValueLabel, title: "単語数")

        let statsStack = UIStackView(arrangedSubviews: [totalStack, streakStack, wordsStack])
        statsStack.axis = .vertical
        statsStack.spacing = 12
        statsStack.translatesAutoresizingMaskIntoConstraints = false

        summaryCard.addSubview(summaryTitleLabel)
        summaryCard.addSubview(statsStack)

        view.addSubview(rangeSegmented)
        view.addSubview(summaryCard)

        NSLayoutConstraint.activate([
            rangeSegmented.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            rangeSegmented.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            summaryCard.topAnchor.constraint(equalTo: rangeSegmented.bottomAnchor, constant: 12),
            summaryCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            summaryTitleLabel.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 12),
            summaryTitleLabel.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            summaryTitleLabel.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),

            statsStack.topAnchor.constraint(equalTo: summaryTitleLabel.bottomAnchor, constant: 12),
            statsStack.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 16),
            statsStack.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -16),
            statsStack.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -16),
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
            totalValueLabel.text = "-"
            streakValueLabel.text = "-"
            wordsValueLabel.text = "-"
            return
        }

        let flipSessions = decoded.sessions.filter { session in
            session.reason == "flip" || session.modeLabel == "フリップ"
        }

        if flipSessions.isEmpty {
            totalValueLabel.text = "-"
            streakValueLabel.text = "-"
            wordsValueLabel.text = "-"
            return
        }

        let filteredSessions = filterSessions(flipSessions)
        let learnedCount = learnedWordCount(from: filteredSessions)
        let totalSeconds = filteredSessions.reduce(0) { $0 + $1.totalElapsedSec }
        let streak = calculateStudyDays(filteredSessions)
        totalValueLabel.text = formatDuration(totalSeconds)
        streakValueLabel.text = "\(streak)日"
        wordsValueLabel.text = "\(learnedCount)"
    }

    private func checkDailyGoalAchievement() {
        guard let goalMinutes = GoalStore.goalMinutesForToday(),
              GoalStore.shouldShowAchievedAlert() else {
            return
        }
        let todayTotal = todayFlipSeconds()
        if todayTotal >= Double(goalMinutes * 60) {
            GoalStore.markAchievedAlertShown()
            let modal = GoalAchievedViewController(minutes: goalMinutes)
            present(modal, animated: true)
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

    @objc private func rangeChanged() {
        reloadResults()
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

    private func calculateStudyDays(_ sessions: [SessionResult]) -> Int {
        let calendar = Calendar.current
        let dates = sessions.compactMap { parseISO($0.timestamp) }
        let daySet = Set(dates.map { calendar.startOfDay(for: $0) })
        return daySet.count
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

    private func filterSessions(_ sessions: [SessionResult]) -> [SessionResult] {
        guard !sessions.isEmpty else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if rangeSegmented.selectedSegmentIndex == 0 {
            return sessions.filter { session in
                guard let date = parseISO(session.timestamp) else { return false }
                return calendar.startOfDay(for: date) == today
            }
        }
        if rangeSegmented.selectedSegmentIndex == 1 {
            guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return sessions }
            return sessions.filter { session in
                guard let date = parseISO(session.timestamp) else { return false }
                let day = calendar.startOfDay(for: date)
                return day >= start && day <= today
            }
        }
        guard let start = calendar.date(byAdding: .day, value: -29, to: today) else { return sessions }
        return sessions.filter { session in
            guard let date = parseISO(session.timestamp) else { return false }
            let day = calendar.startOfDay(for: date)
            return day >= start && day <= today
        }
    }

    private func normalizeKey(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func parseISO(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso)
    }

    private func makeStatStack(titleLabel: UILabel, valueLabel: UILabel, title: String) -> UIStackView {
        titleLabel.text = title
        titleLabel.numberOfLines = 1
        titleLabel.textAlignment = .left
        valueLabel.textAlignment = .left
        valueLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)

        [summaryCard].forEach { card in
            card.backgroundColor = palette.surface
            card.layer.borderColor = palette.border.cgColor
        }

        summaryTitleLabel.font = AppFont.title(size: 14)
        summaryTitleLabel.textColor = palette.text

        [totalTitleLabel, streakTitleLabel, wordsTitleLabel].forEach { label in
            label.font = AppFont.jp(size: 13, weight: .bold)
            label.textColor = palette.mutedText
        }
        [totalValueLabel, streakValueLabel, wordsValueLabel].forEach { label in
            label.font = AppFont.jp(size: 18, weight: .bold)
            label.textColor = palette.text
        }
        let attrs = [NSAttributedString.Key.font: AppFont.jp(size: 12, weight: .bold)]
        rangeSegmented.setTitleTextAttributes(attrs, for: .normal)
        rangeSegmented.setTitleTextAttributes(attrs, for: .selected)
        rangeSegmented.selectedSegmentTintColor = palette.accent
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func showAlert(title: String, message: String) {
        presentUnifiedModal(title: title,
                            message: message,
                            actions: [UnifiedModalAction(title: "OK")])
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
