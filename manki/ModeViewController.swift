//
//  ModeViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

private final class HeartButton: UIButton {
    private let fillLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private var fillColor: UIColor = .systemYellow
    private var borderColor: UIColor = .black

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.insertSublayer(fillLayer, at: 0)
        layer.insertSublayer(borderLayer, above: fillLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.insertSublayer(fillLayer, at: 0)
        layer.insertSublayer(borderLayer, above: fillLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = bounds.insetBy(dx: 0.4, dy: 0.4)
        let path = heartBezierPath(in: rect).cgPath
        fillLayer.frame = bounds
        fillLayer.path = path
        fillLayer.fillColor = fillColor.cgColor
        fillLayer.strokeColor = UIColor.clear.cgColor

        borderLayer.frame = bounds
        borderLayer.path = path
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = borderColor.cgColor
        borderLayer.lineWidth = 2

        layer.shadowPath = path
        layer.shadowColor = borderColor.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 4
    }

    func applyHeartStyle(fill: UIColor, border: UIColor, textColor: UIColor) {
        fillColor = fill
        borderColor = border
        setTitleColor(textColor, for: .normal)
        setNeedsLayout()
    }

    private func heartBezierPath(in rect: CGRect) -> UIBezierPath {
        let w = rect.width
        let h = rect.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.95))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.38),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.86),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.60))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.28, y: rect.minY + h * 0.10),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.20),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.10))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.23),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.37, y: rect.minY + h * 0.10),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.46, y: rect.minY + h * 0.18))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.10),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.54, y: rect.minY + h * 0.18),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.63, y: rect.minY + h * 0.10))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.38),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.10),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.20))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.95),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.60),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.86))
        path.close()
        return path
    }
}

class ModeViewController: UIViewController {

    private let backgroundImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeartButtons()
    }

    private lazy var studyButton: HeartButton = makeButton(
        title: "Study",
        action: #selector(goToStudyMenu)
    )

    private lazy var goalMenuButton: HeartButton = makeButton(
        title: "Goal",
        action: #selector(goToGoalMenu)
    )

    private lazy var settingButton: HeartButton = makeButton(
        title: "Setting",
        action: #selector(goToSetting)
    )

    private func setupUI() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.alpha = 0.8

        titleLabel.text = "MANKI"
        titleLabel.textAlignment = .center
        subtitleLabel.text = "Select Mode"
        subtitleLabel.textAlignment = .center

        view.addSubview(backgroundImageView)
        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            studyButton,
            goalMenuButton,
            settingButton
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = AppSpacing.s(10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        let centerY = stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        centerY.priority = .defaultLow
        NSLayoutConstraint.activate([
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerY,
            stack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(16)),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppSpacing.s(16)),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.88),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 260),

            titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            subtitleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),

            studyButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.46),
            goalMenuButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.46),
            settingButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.46),

            studyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 170),
            goalMenuButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 170),
            settingButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 170),

            studyButton.widthAnchor.constraint(lessThanOrEqualToConstant: 210),
            goalMenuButton.widthAnchor.constraint(lessThanOrEqualToConstant: 210),
            settingButton.widthAnchor.constraint(lessThanOrEqualToConstant: 210)
        ])
    }

    private func makeButton(title: String, action: Selector) -> HeartButton {
        let button = HeartButton(frame: .zero)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        button.titleEdgeInsets = UIEdgeInsets(top: AppSpacing.s(6), left: 0, bottom: 0, right: 0)
        let preferredHeight = button.heightAnchor.constraint(equalToConstant: 138)
        preferredHeight.priority = .defaultHigh
        preferredHeight.isActive = true
        let minHeight = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 126)
        minHeight.priority = .defaultLow
        minHeight.isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func goToStudyMenu() {
        let controller = ModeMenuViewController(
            menuTitle: "Study",
            firstButtonTitle: "ステッカー",
            secondButtonTitle: "フォルダー"
        )
        controller.onFirstTapped = { [weak self] in
            self?.openSticker()
        }
        controller.onSecondTapped = { [weak self] in
            self?.openFolder()
        }
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func goToGoalMenu() {
        let controller = ModeMenuViewController(
            menuTitle: "Goal",
            firstButtonTitle: "スケジュール/履歴",
            secondButtonTitle: "目標設定"
        )
        controller.onFirstTapped = { [weak self] in
            self?.openScheduleAndHistory()
        }
        controller.onSecondTapped = { [weak self] in
            self?.openGoalSetting()
        }
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func openFolder() {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "FolderNavigationController") else {
            return
        }
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func openScheduleAndHistory() {
        guard let tabBar = storyboard?.instantiateViewController(withIdentifier: "MainTabBarController") else {
            return
        }
        let nav = UINavigationController(rootViewController: tabBar)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func goToSetting() {
        let controller = SettingViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func openSticker() {
        let controller = StiCamViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func openGoalSetting() {
        let controller = GoalViewController()
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        view.backgroundColor = palette.background
        backgroundImageView.image = backgroundImage(for: ThemeManager.current)
        titleLabel.font = AppFont.title(size: 20)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.jp(size: 18, weight: .bold)
        subtitleLabel.textColor = palette.mutedText
        studyButton.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        goalMenuButton.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        settingButton.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        studyButton.applyHeartStyle(fill: palette.accent, border: palette.border, textColor: palette.text)
        goalMenuButton.applyHeartStyle(fill: palette.accentStrong, border: palette.border, textColor: palette.text)
        settingButton.applyHeartStyle(fill: palette.surfaceAlt, border: palette.border, textColor: palette.text)
    }

    private func updateHeartButtons() {
        studyButton.setNeedsLayout()
        goalMenuButton.setNeedsLayout()
        settingButton.setNeedsLayout()
    }

    private func backgroundImage(for theme: AppTheme) -> UIImage? {
        let baseName: String
        switch theme {
        case .pink:
            baseName = "pnk"
        case .purple:
            baseName = "prpl"
        case .green:
            baseName = "grrn"
        case .yellow:
            baseName = "yllw"
        case .blue:
            baseName = "bleu"
        }
        if let image = UIImage(named: baseName) {
            return image
        }
        let extensions = ["png", "jpg", "jpeg"]
        for ext in extensions {
            if let path = Bundle.main.path(forResource: baseName, ofType: ext),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
