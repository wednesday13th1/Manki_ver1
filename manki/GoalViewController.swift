//
//  GoalViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/02/01.
//

import UIKit

final class GoalViewController: UIViewController, UITextFieldDelegate {

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
    private let maxMinutes = 300
    private let stepMinutes = 5
    private let resultsFileName = "results.json"

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
        let initial = GoalStore.goalMinutesForToday()
            ?? GoalStore.lastSavedMinutes()
            ?? 30
        updateGoal(minutes: initial, syncText: true)
        updateLuckyVisibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLuckyVisibility()
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
        slider.maximumValue = Float(maxMinutes)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        valueLabel.textAlignment = .center

        saveButton.setTitle("保存", for: .normal)
        saveButton.addTarget(self, action: #selector(saveGoal), for: .touchUpInside)

        luckyButton.setTitle("メッセージガチャ", for: .normal)
        luckyButton.addTarget(self, action: #selector(openLucky), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            minutesField,
            slider,
            valueLabel
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(saveButton)
        view.addSubview(luckyButton)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            saveButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
            saveButton.heightAnchor.constraint(equalToConstant: 48),
            luckyButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 12),
            luckyButton.heightAnchor.constraint(equalToConstant: 44),
            luckyButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButtonLeading = saveButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        saveButtonTrailing = saveButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        saveButtonLeading?.isActive = true
        saveButtonTrailing?.isActive = true
        luckyButton.translatesAutoresizingMaskIntoConstraints = false
        luckyButtonLeading = luckyButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        luckyButtonTrailing = luckyButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        luckyButtonLeading?.isActive = true
        luckyButtonTrailing?.isActive = true

        minutesField.heightAnchor.constraint(equalToConstant: 44).isActive = true
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
        ThemeManager.stylePrimaryButton(saveButton)
        saveButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        ThemeManager.styleSecondaryButton(luckyButton)
        luckyButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: pixelFont], for: .normal)
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: pixelFont], for: .highlighted)
    }

    private func updateGoal(minutes: Int, syncText: Bool) {
        let clamped = max(minMinutes, min(maxMinutes, minutes))
        let stepped = (clamped / stepMinutes) * stepMinutes
        slider.value = Float(stepped)
        valueLabel.text = "\(stepped)分"
        if syncText {
            minutesField.text = "\(stepped)"
        }
    }

    private func updateLuckyVisibility() {
        guard let goalMinutes = GoalStore.goalMinutesForToday() else {
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
        let clamped = max(minMinutes, min(maxMinutes, minutes))
        GoalStore.setGoal(minutes: clamped)
        let alert = UIAlertController(title: "保存しました", message: "目標 \(clamped)分", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
