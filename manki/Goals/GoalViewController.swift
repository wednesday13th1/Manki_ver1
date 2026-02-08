//
//  GoalViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/02/01.
//

import UIKit

final class GoalViewController: UIViewController, UITextFieldDelegate {

    private let periodSegmented = UISegmentedControl(items: ["1日", "1週間", "1ヶ月"])
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let minutesField = UITextField()
    private let slider = UISlider()
    private let valueLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let luckyButton = UIButton(type: .system)
    private var saveButtonLeading: NSLayoutConstraint?
    private var saveButtonTrailing: NSLayoutConstraint?
    private var luckyButtonLeading: NSLayoutConstraint?
    private var luckyButtonTrailing: NSLayoutConstraint?
    private var themeObserver: NSObjectProtocol?

    private let minMinutes = 0
    private let dayMaxMinutes = 300
    private let weekMaxMinutes = 2100
    private let monthMaxMinutes = 9000
    private let stepMinutes = 5
    private let defaultGoalMinutes = 30
    private let resultsFileName = "results.json"

    private var selectedPeriod: GoalPeriod {
        GoalPeriod(rawValue: periodSegmented.selectedSegmentIndex) ?? .day
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureNavigation()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
        refreshGoalFromStore(syncText: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshGoalFromStore(syncText: true)
    }

    private func configureNavigation() {
        title = "目標設定"
        let backItem = UIBarButtonItem(
            title: "戻る",
            style: .plain,
            target: self,
            action: #selector(closeSelf)
        )
        navigationItem.leftBarButtonItem = backItem
    }

    private func configureUI() {
        periodSegmented.selectedSegmentIndex = 0
        periodSegmented.addTarget(self, action: #selector(periodChanged), for: .valueChanged)

        titleLabel.text = "1日の勉強時間目標"
        titleLabel.textAlignment = .center

        subtitleLabel.text = "分数を入力 or スライダーで選択"
        subtitleLabel.textAlignment = .center

        minutesField.borderStyle = .roundedRect
        minutesField.placeholder = "例: 30"
        minutesField.keyboardType = .numberPad
        minutesField.textAlignment = .center
        minutesField.delegate = self
        minutesField.addTarget(self, action: #selector(textChanged), for: .editingChanged)

        slider.minimumValue = Float(minMinutes)
        slider.maximumValue = Float(dayMaxMinutes)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        valueLabel.textAlignment = .center

        saveButton.setTitle("保存", for: .normal)
        saveButton.addTarget(self, action: #selector(saveGoal), for: .touchUpInside)

        luckyButton.setTitle("メッセージガチャ", for: .normal)
        luckyButton.addTarget(self, action: #selector(openLucky), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            periodSegmented,
            titleLabel,
            subtitleLabel,
            minutesField,
            slider,
            valueLabel
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(saveButton)
        view.addSubview(luckyButton)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            saveButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
            luckyButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 12),
            luckyButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButtonLeading = saveButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40)
        saveButtonTrailing = saveButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40)
        saveButtonLeading?.isActive = true
        saveButtonTrailing?.isActive = true
        luckyButton.translatesAutoresizingMaskIntoConstraints = false
        luckyButtonLeading = luckyButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40)
        luckyButtonTrailing = luckyButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40)
        luckyButtonLeading?.isActive = true
        luckyButtonTrailing?.isActive = true

        let savePreferredHeight = saveButton.heightAnchor.constraint(equalToConstant: 48)
        savePreferredHeight.priority = .defaultHigh
        savePreferredHeight.isActive = true
        let saveMinHeight = saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        saveMinHeight.priority = .defaultLow
        saveMinHeight.isActive = true

        let luckyPreferredHeight = luckyButton.heightAnchor.constraint(equalToConstant: 44)
        luckyPreferredHeight.priority = .defaultHigh
        luckyPreferredHeight.isActive = true
        let luckyMinHeight = luckyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        luckyMinHeight.priority = .defaultLow
        luckyMinHeight.isActive = true

        let minutesPreferredHeight = minutesField.heightAnchor.constraint(equalToConstant: 44)
        minutesPreferredHeight.priority = .defaultHigh
        minutesPreferredHeight.isActive = true
        let minutesMinHeight = minutesField.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        minutesMinHeight.priority = .defaultLow
        minutesMinHeight.isActive = true
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        let pixelFont = AppFont.jp(size: 16, weight: .bold)
        titleLabel.font = AppFont.jp(size: 20, weight: .bold)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.jp(size: 14)
        subtitleLabel.textColor = palette.mutedText
        minutesField.font = AppFont.jp(size: 16, weight: .bold)
        minutesField.backgroundColor = palette.surface
        minutesField.textColor = palette.text
        minutesField.layer.cornerRadius = 10
        minutesField.layer.borderWidth = 1
        minutesField.layer.borderColor = palette.border.cgColor
        valueLabel.font = AppFont.jp(size: 16, weight: .bold)
        valueLabel.textColor = palette.text
        let segmentAttrs: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 12, weight: .bold),
            .foregroundColor: palette.text
        ]
        periodSegmented.setTitleTextAttributes(segmentAttrs, for: .normal)
        periodSegmented.setTitleTextAttributes(segmentAttrs, for: .selected)
        periodSegmented.selectedSegmentTintColor = palette.accent
        periodSegmented.backgroundColor = palette.surface
        periodSegmented.layer.borderWidth = 1
        periodSegmented.layer.borderColor = palette.border.cgColor
        ThemeManager.stylePrimaryButton(saveButton)
        saveButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        ThemeManager.styleSecondaryButton(luckyButton)
        luckyButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: pixelFont], for: .normal)
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: pixelFont], for: .highlighted)
    }

    private func updateGoal(minutes: Int, syncText: Bool) {
        let clamped = max(minMinutes, min(maxMinutes(for: selectedPeriod), minutes))
        let stepped = (clamped / stepMinutes) * stepMinutes
        slider.value = Float(stepped)
        valueLabel.text = "\(stepped)分"
        if syncText {
            minutesField.text = "\(stepped)"
        }
    }

    private func updateLuckyVisibility() {
        guard selectedPeriod == .day,
              let goalMinutes = GoalStore.goalMinutesForToday() else {
            luckyButton.isHidden = true
            return
        }
        let todayTotal = todayFlipSeconds()
        luckyButton.isHidden = todayTotal < Double(goalMinutes * 60)
    }

    private func resultsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(resultsFileName)
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

    private func parseISO(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso)
    }

    @objc private func sliderChanged() {
        let raw = Int(slider.value.rounded())
        updateGoal(minutes: raw, syncText: true)
    }

    @objc private func periodChanged() {
        updatePeriodLabels()
        updateSliderRange()
        refreshGoalFromStore(syncText: true)
    }

    @objc private func textChanged() {
        let text = minutesField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let minutes = Int(text) else { return }
        updateGoal(minutes: minutes, syncText: false)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        let text = minutesField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let minutes = Int(text) ?? 0
        updateGoal(minutes: minutes, syncText: true)
    }

    @objc private func saveGoal() {
        let text = minutesField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let minutes = Int(text) ?? Int(slider.value.rounded())
        let clamped = max(minMinutes, min(maxMinutes(for: selectedPeriod), minutes))
        GoalStore.setGoal(minutes: clamped, period: selectedPeriod)
        updateSaveButtonTitle()
        updateLuckyVisibility()
        presentUnifiedModal(
            title: "保存しました",
            message: "目標 \(clamped)分",
            actions: [UnifiedModalAction(title: "OK")]
        )
    }

    @objc private func openLucky() {
        let controller = LuckyViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func updatePeriodLabels() {
        switch selectedPeriod {
        case .day:
            titleLabel.text = "1日の勉強時間目標"
        case .week:
            titleLabel.text = "1週間の勉強時間目標"
        case .month:
            titleLabel.text = "1ヶ月の勉強時間目標"
        }
    }

    private func updateSliderRange() {
        slider.minimumValue = Float(minMinutes)
        slider.maximumValue = Float(maxMinutes(for: selectedPeriod))
    }

    private func refreshGoalFromStore(syncText: Bool) {
        let minutes = GoalStore.goalMinutes(for: selectedPeriod)
            ?? GoalStore.lastSavedMinutes(for: selectedPeriod)
            ?? defaultGoalMinutes
        updatePeriodLabels()
        updateSliderRange()
        updateGoal(minutes: minutes, syncText: syncText)
        updateSaveButtonTitle()
        updateLuckyVisibility()
    }

    private func updateSaveButtonTitle() {
        if GoalStore.goalMinutes(for: selectedPeriod) != nil {
            saveButton.setTitle("変更", for: .normal)
        } else {
            saveButton.setTitle("保存", for: .normal)
        }
    }

    private func maxMinutes(for period: GoalPeriod) -> Int {
        switch period {
        case .day:
            return dayMaxMinutes
        case .week:
            return weekMaxMinutes
        case .month:
            return monthMaxMinutes
        }
    }
}

private struct ResultsDatabase: Codable {
    let sessions: [SessionResult]
}

private struct SessionResult: Codable {
    let timestamp: String
    let reason: String
    let modeLabel: String?
    let totalElapsedSec: Double
}
