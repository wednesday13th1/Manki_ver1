//
//  SettingViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/25.
//

import UIKit
import PhotosUI

class SettingViewController: UIViewController, PHPickerViewControllerDelegate {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let themeTitleLabel = UILabel()
    private let backgroundTitleLabel = UILabel()
    private let opacityTitleLabel = UILabel()
    private let opacityValueLabel = UILabel()
    private let themeStack = UIStackView()
    private let backgroundButton = UIButton(type: .system)
    private let opacitySlider = UISlider()
    private var themeButtons: [UIButton] = []
    private let cardView = UIView()
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Setting"
        configureUI()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "閉じる",
            style: .plain,
            target: self,
            action: #selector(closeSelf)
        )
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }
 
    private func configureUI() {
        titleLabel.text = "THEME"
        titleLabel.textAlignment = .center
        subtitleLabel.text = "Pick your color"
        subtitleLabel.textAlignment = .center
        themeTitleLabel.text = "テーマカラー"
        themeTitleLabel.textAlignment = .left
        backgroundTitleLabel.text = "背景画像"
        backgroundTitleLabel.textAlignment = .left
        opacityTitleLabel.text = "背景の透明度"
        opacityTitleLabel.textAlignment = .left
        opacityValueLabel.textAlignment = .right

        themeStack.axis = .horizontal
        themeStack.spacing = AppSpacing.s(12)
        themeStack.alignment = .center
        themeStack.distribution = .fillEqually
        themeStack.translatesAutoresizingMaskIntoConstraints = false

        backgroundButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundButton.setTitle("背景を選ぶ", for: .normal)
        backgroundButton.addTarget(self, action: #selector(openBackgroundMenu), for: .touchUpInside)

        opacitySlider.translatesAutoresizingMaskIntoConstraints = false
        opacitySlider.minimumValue = 0.2
        opacitySlider.maximumValue = 1.0
        opacitySlider.addTarget(self, action: #selector(opacityChanged(_:)), for: .valueChanged)

        themeButtons = AppTheme.allCases.enumerated().map { index, theme in
            let button = UIButton(type: .system)
            button.tag = index
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 2
            button.addTarget(self, action: #selector(selectTheme(_:)), for: .touchUpInside)
            return button
        }
        themeButtons.forEach { themeStack.addArrangedSubview($0) }

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, cardView])
        stack.axis = .vertical
        stack.spacing = AppSpacing.s(12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        cardView.addSubview(themeTitleLabel)
        cardView.addSubview(themeStack)
        cardView.addSubview(backgroundTitleLabel)
        cardView.addSubview(backgroundButton)
        cardView.addSubview(opacityTitleLabel)
        cardView.addSubview(opacityValueLabel)
        cardView.addSubview(opacitySlider)
        themeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        opacityValueLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(16)),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(16)),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(16)),

            cardView.heightAnchor.constraint(equalToConstant: 300),

            themeTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppSpacing.s(12)),
            themeTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            themeTitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),

            themeStack.topAnchor.constraint(equalTo: themeTitleLabel.bottomAnchor, constant: AppSpacing.s(12)),
            themeStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            themeStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            themeStack.heightAnchor.constraint(equalToConstant: 36),

            backgroundTitleLabel.topAnchor.constraint(equalTo: themeStack.bottomAnchor, constant: AppSpacing.s(20)),
            backgroundTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            backgroundTitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),

            backgroundButton.topAnchor.constraint(equalTo: backgroundTitleLabel.bottomAnchor, constant: AppSpacing.s(10)),
            backgroundButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            backgroundButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            backgroundButton.heightAnchor.constraint(equalToConstant: 40),

            opacityTitleLabel.topAnchor.constraint(equalTo: backgroundButton.bottomAnchor, constant: AppSpacing.s(16)),
            opacityTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            opacityTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: opacityValueLabel.leadingAnchor, constant: -AppSpacing.s(8)),

            opacityValueLabel.centerYAnchor.constraint(equalTo: opacityTitleLabel.centerYAnchor),
            opacityValueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
            opacityValueLabel.widthAnchor.constraint(equalToConstant: 56),

            opacitySlider.topAnchor.constraint(equalTo: opacityTitleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            opacitySlider.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppSpacing.s(16)),
            opacitySlider.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppSpacing.s(16)),
        ])
    }

    @objc private func openBackgroundMenu() {
        let alert = UIAlertController(title: "背景画像", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "写真を選ぶ", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        if ThemeManager.modeBackgroundImage() != nil {
            alert.addAction(UIAlertAction(title: "背景をリセット", style: .destructive) { [weak self] _ in
                ThemeManager.clearModeBackgroundImage()
                self?.updateBackgroundButtonTitle()
            })
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = backgroundButton
            popover.sourceRect = backgroundButton.bounds
        }
        present(alert, animated: true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else {
                return
            }
            ThemeManager.saveModeBackgroundImage(image)
            DispatchQueue.main.async {
                self?.updateBackgroundButtonTitle()
            }
        }
    }

    @objc private func opacityChanged(_ sender: UISlider) {
        ThemeManager.setModeBackgroundAlpha(CGFloat(sender.value))
        updateOpacityValueLabel()
    }

    @objc private func selectTheme(_ sender: UIButton) {
        let themes = AppTheme.allCases
        guard sender.tag >= 0, sender.tag < themes.count else { return }
        ThemeManager.setTheme(themes[sender.tag])
        updateThemeSelection()
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        if let navigationBar = navigationController?.navigationBar {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = palette.surface
            appearance.titleTextAttributes = [
                .foregroundColor: palette.text,
                .font: AppFont.jp(size: 18, weight: .bold)
            ]
            appearance.shadowColor = palette.border
            let barAttributes: [NSAttributedString.Key: Any] = [
                .font: AppFont.jp(size: 14, weight: .bold),
                .foregroundColor: palette.text
            ]
            appearance.buttonAppearance.normal.titleTextAttributes = barAttributes
            appearance.buttonAppearance.highlighted.titleTextAttributes = barAttributes
            appearance.doneButtonAppearance.normal.titleTextAttributes = barAttributes
            appearance.doneButtonAppearance.highlighted.titleTextAttributes = barAttributes
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.tintColor = palette.text
        }

        titleLabel.font = AppFont.title(size: 18)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.en(size: 20)
        subtitleLabel.textColor = palette.mutedText
        themeTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        themeTitleLabel.textColor = palette.text
        backgroundTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        backgroundTitleLabel.textColor = palette.text
        opacityTitleLabel.font = AppFont.jp(size: 15, weight: .bold)
        opacityTitleLabel.textColor = palette.text
        opacityValueLabel.font = AppFont.en(size: 18)
        opacityValueLabel.textColor = palette.text

        cardView.backgroundColor = palette.surface
        cardView.layer.borderColor = palette.border.cgColor
        backgroundButton.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
        ThemeManager.styleSecondaryButton(backgroundButton)
        opacitySlider.minimumTrackTintColor = palette.accentStrong
        opacitySlider.maximumTrackTintColor = palette.surfaceAlt
        opacitySlider.tintColor = palette.accent
        opacitySlider.value = Float(ThemeManager.modeBackgroundAlpha)
        updateOpacityValueLabel()
        updateBackgroundButtonTitle()

        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            button.backgroundColor = ThemeManager.palette(for: theme).accent
        }
        updateThemeSelection()
    }

    private func updateBackgroundButtonTitle() {
        let hasCustomBackground = ThemeManager.modeBackgroundImage() != nil
        let title = hasCustomBackground ? "背景を変更する" : "背景を選ぶ"
        backgroundButton.setTitle(title, for: .normal)
    }

    private func updateOpacityValueLabel() {
        let percent = Int(round(ThemeManager.modeBackgroundAlpha * 100))
        opacityValueLabel.text = "\(percent)%"
    }

    private func updateThemeSelection() {
        let current = ThemeManager.current
        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            if theme == current {
                button.layer.borderColor = ThemeManager.palette().border.cgColor
                button.layer.shadowColor = ThemeManager.palette().border.cgColor
                button.layer.shadowOpacity = 0.25
                button.layer.shadowOffset = CGSize(width: 0, height: 2)
                button.layer.shadowRadius = 4
            } else {
                button.layer.borderColor = UIColor.clear.cgColor
                button.layer.shadowOpacity = 0
            }
        }
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
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
