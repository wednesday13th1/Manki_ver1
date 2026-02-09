//
//  StiCamViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/29.
//

import UIKit
import PhotosUI

final class StiCamViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let previewImageView = UIImageView()
    private let filterControl = UISegmentedControl(items: ["モノクロ", "セピア"])
    private let captureButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let collectionButton = UIButton(type: .system)
    private let drawButton = UIButton(type: .system)
    private let emojiButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private var baseStickerImage: UIImage?
    private var originalImage: UIImage?
    private var selectedEmoji: String?
    private var pendingStickerImage: UIImage?
    private var themeObserver: NSObjectProtocol?
    private enum FilterMode: Int {
        case noir = 0
        case sepia = 1
    }
    private var filterMode: FilterMode = .noir

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Sticker Mode"
        view.backgroundColor = .systemBackground
        ThemeManager.applyNavigationAppearance(to: navigationController)
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "戻る", style: .plain, target: nil, action: nil)
        configureNavigation()
        configureTitleFont()
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

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func configureNavigation() {
        if navigationController?.viewControllers.first == self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "戻る",
                                                               style: .done,
                                                               target: self,
                                                               action: #selector(closeTapped))
        }
    }

    private func configureTitleFont() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        var attributes = navigationBar.titleTextAttributes ?? [:]
        attributes[.font] = AppFont.en(size: 18, weight: .regular)
        navigationBar.titleTextAttributes = attributes
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([
            .font: AppFont.jp(size: 14, weight: .regular)
        ], for: .normal)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func configureUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.text = ""
        hintLabel.font = AppFont.jp(size: 14)
        hintLabel.textAlignment = .center

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.backgroundColor = UIColor.systemGray6
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.clipsToBounds = true
        previewImageView.layer.cornerRadius = 16

        filterControl.translatesAutoresizingMaskIntoConstraints = false
        filterControl.selectedSegmentIndex = 0
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)

        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setTitle("カメラ", for: .normal)
        captureButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)

        drawButton.translatesAutoresizingMaskIntoConstraints = false
        drawButton.setTitle("手書き", for: .normal)
        drawButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        drawButton.addTarget(self, action: #selector(drawTapped), for: .touchUpInside)

        emojiButton.translatesAutoresizingMaskIntoConstraints = false
        emojiButton.setTitle("絵文字", for: .normal)
        emojiButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        emojiButton.isEnabled = true
        emojiButton.addTarget(self, action: #selector(emojiTapped), for: .touchUpInside)

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("ステッカー保存", for: .normal)
        saveButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        saveButton.isEnabled = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        collectionButton.translatesAutoresizingMaskIntoConstraints = false
        collectionButton.setTitle("コレクションを見る", for: .normal)
        collectionButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        collectionButton.addTarget(self, action: #selector(collectionTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [captureButton, drawButton, emojiButton, saveButton, collectionButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = AppSpacing.s(12)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(hintLabel)
        contentView.addSubview(previewImageView)
        contentView.addSubview(filterControl)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            hintLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(20)),
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(20)),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(20)),

            previewImageView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: AppSpacing.s(16)),
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(24)),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(24)),
            previewImageView.heightAnchor.constraint(equalTo: previewImageView.widthAnchor),

            filterControl.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: AppSpacing.s(12)),
            filterControl.leadingAnchor.constraint(equalTo: previewImageView.leadingAnchor),
            filterControl.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor),

            buttonStack.topAnchor.constraint(equalTo: filterControl.bottomAnchor, constant: AppSpacing.s(16)),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(24)),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(24)),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(24))
        ])
    }

    @objc private func captureTapped() {
        var actions: [UnifiedModalAction] = []
        #if targetEnvironment(simulator)
        actions.append(UnifiedModalAction(title: "フォトライブラリ") { [weak self] in
            self?.presentPhotoPicker()
        })
        #else
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actions.append(UnifiedModalAction(title: "カメラ") { [weak self] in
                self?.presentCamera()
            })
        }
        actions.append(UnifiedModalAction(title: "フォトライブラリ") { [weak self] in
            self?.presentPhotoPicker()
        })
        #endif
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "画像を選択", message: nil, actions: actions)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker()
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func saveTapped() {
        guard let stickerImage = pendingStickerImage else {
            showAlert(title: "未撮影", message: "先に写真を撮影してください。")
            return
        }
        guard let fileName = StickerStore.saveStickerImage(stickerImage) else {
            showAlert(title: "保存エラー", message: "ステッカーの保存に失敗しました。")
            return
        }
        var stickers = StickerStore.loadStickers()
        stickers.insert(SavedSticker(imageFileName: fileName), at: 0)
        StickerStore.saveStickers(stickers)
        saveButton.isEnabled = false
        showAlert(title: "保存しました", message: "ステッカーをコレクションに追加しました。")
    }

    @objc private func collectionTapped() {
        let collectionVC = StiCollectViewController()
        if let navigationController {
            navigationController.pushViewController(collectionVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: collectionVC)
            present(nav, animated: true)
        }
    }

    @objc private func drawTapped() {
        let drawVC = StiDrawViewController()
        drawVC.onSave = { [weak self] image in
            guard let self else { return }
            originalImage = image
            baseStickerImage = makeStickerImage(from: applyFilterIfNeeded(to: image))
            selectedEmoji = nil
            updatePreview()
        }
        navigationController?.pushViewController(drawVC, animated: true)
    }

    @objc private func emojiTapped() {
        let emojiField = UITextField()
        emojiField.borderStyle = .roundedRect
        emojiField.placeholder = "😀"
        emojiField.textAlignment = .center
        presentUnifiedModal(
            title: "絵文字を追加",
            message: "使いたい絵文字を1つ入力してください。",
            contentView: emojiField,
            actions: [
                UnifiedModalAction(title: "キャンセル", style: .cancel),
                UnifiedModalAction(title: "追加") { [weak self] in
                    guard let self else { return }
                    let text = emojiField.text ?? ""
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let firstCharacter = trimmed.first else {
                        self.showAlert(title: "入力エラー", message: "絵文字を入力してください。")
                        return
                    }
                    self.selectedEmoji = String(firstCharacter)
                    self.updatePreview()
                }
            ]
        )
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let pickedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        if let pickedImage {
            originalImage = pickedImage
            baseStickerImage = makeStickerImage(from: applyFilterIfNeeded(to: pickedImage))
            selectedEmoji = nil
            updatePreview()
        } else {
            showAlert(title: "取得エラー", message: "画像を取得できませんでした。")
        }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
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
        guard let provider = results.first?.itemProvider else { return }
        guard provider.canLoadObject(ofClass: UIImage.self) else {
            showAlert(title: "取得エラー", message: "画像を読み込めませんでした。")
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.originalImage = image
                    let filtered = self?.applyFilterIfNeeded(to: image) ?? image
                    self?.baseStickerImage = self?.makeStickerImage(from: filtered)
                    self?.selectedEmoji = nil
                    self?.updatePreview()
                } else {
                    self?.showAlert(title: "取得エラー", message: error?.localizedDescription ?? "画像を取得できませんでした。")
                }
            }
        }
    }

    private func makeStickerImage(from image: UIImage) -> UIImage {
        let squareImage = makeSquareImage(from: image, size: 512)
        let renderer = UIGraphicsImageRenderer(size: squareImage.size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: squareImage.size)
            let path = UIBezierPath(ovalIn: rect)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.clip()
            squareImage.draw(in: rect)
            context.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            context.cgContext.setLineWidth(10)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.strokePath()
        }
    }

    private func updatePreview() {
        let updatedImage: UIImage?
        if let originalImage {
            let filtered = applyFilterIfNeeded(to: originalImage)
            let base = makeStickerImage(from: filtered)
            if let emoji = selectedEmoji {
                updatedImage = applyEmoji(emoji, to: base)
            } else {
                updatedImage = base
            }
        } else if let emoji = selectedEmoji {
            updatedImage = makeEmojiSticker(emoji)
        } else {
            updatedImage = nil
        }
        baseStickerImage = updatedImage
        pendingStickerImage = updatedImage
        previewImageView.image = updatedImage
        saveButton.isEnabled = (updatedImage != nil)
    }

    @objc private func filterChanged() {
        filterMode = FilterMode(rawValue: filterControl.selectedSegmentIndex) ?? .noir
        updatePreview()
    }

    private func applyFilterIfNeeded(to image: UIImage) -> UIImage {
        switch filterMode {
        case .noir:
            return applyFilter(name: "CIPhotoEffectNoir", to: image)
        case .sepia:
            return applyFilter(name: "CISepiaTone", to: image, intensity: 0.85)
        }
    }

    private func applyFilter(name: String, to image: UIImage, intensity: CGFloat? = nil) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        guard let filter = CIFilter(name: name) else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        if let intensity {
            filter.setValue(intensity, forKey: kCIInputIntensityKey)
        }
        guard let output = filter.outputImage else { return image }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func applyEmoji(_ emoji: String, to image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: image.size)
            image.draw(in: rect)
            let fontSize = image.size.width * 0.35
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: UIColor.white
            ]
            let emojiSize = (emoji as NSString).size(withAttributes: attributes)
            let origin = CGPoint(
                x: (image.size.width - emojiSize.width) / 2,
                y: (image.size.height - emojiSize.height) / 2
            )
            (emoji as NSString).draw(at: origin, withAttributes: attributes)
        }
    }

    private func makeEmojiSticker(_ emoji: String) -> UIImage {
        let size: CGFloat = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            let path = UIBezierPath(ovalIn: rect)
            context.cgContext.setFillColor(UIColor.systemGray6.cgColor)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.fillPath()
            context.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            context.cgContext.setLineWidth(10)
            context.cgContext.addPath(path.cgPath)
            context.cgContext.strokePath()

            let fontSize = size * 0.45
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: UIColor.white
            ]
            let emojiSize = (emoji as NSString).size(withAttributes: attributes)
            let origin = CGPoint(
                x: (size - emojiSize.width) / 2,
                y: (size - emojiSize.height) / 2
            )
            (emoji as NSString).draw(at: origin, withAttributes: attributes)
        }
    }

    private func makeSquareImage(from image: UIImage, size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let scale = max(size / image.size.width, size / image.size.height)
            let width = image.size.width * scale
            let height = image.size.height * scale
            let origin = CGPoint(x: (size - width) / 2, y: (size - height) / 2)
            image.draw(in: CGRect(origin: origin, size: CGSize(width: width, height: height)))
        }
    }

    private func showAlert(title: String, message: String) {
        presentUnifiedModal(title: title,
                            message: message,
                            actions: [UnifiedModalAction(title: "OK")])
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)

        hintLabel.textColor = palette.text
        previewImageView.backgroundColor = palette.surfaceAlt

        ThemeManager.stylePrimaryButton(captureButton)
        ThemeManager.styleSecondaryButton(drawButton)
        ThemeManager.styleSecondaryButton(emojiButton)
        ThemeManager.stylePrimaryButton(saveButton)
        ThemeManager.styleSecondaryButton(collectionButton)

        filterControl.selectedSegmentTintColor = palette.accent
        filterControl.setTitleTextAttributes([.foregroundColor: palette.text], for: .selected)
        filterControl.setTitleTextAttributes([.foregroundColor: palette.mutedText], for: .normal)
    }
}
