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
    private let captureButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let collectionButton = UIButton(type: .system)
    private let drawButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private var pendingStickerImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Sticker Mode"
        view.backgroundColor = .systemBackground
        configureNavigation()
        configureTitleFont()
        configureUI()
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

        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setTitle("カメラ", for: .normal)
        captureButton.titleLabel?.font = AppFont.jp(size: 18, weight: .regular)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)

        drawButton.translatesAutoresizingMaskIntoConstraints = false
        drawButton.setTitle("手書き", for: .normal)
        drawButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        drawButton.addTarget(self, action: #selector(drawTapped), for: .touchUpInside)

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("ステッカー保存", for: .normal)
        saveButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        saveButton.isEnabled = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        collectionButton.translatesAutoresizingMaskIntoConstraints = false
        collectionButton.setTitle("コレクションを見る", for: .normal)
        collectionButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        collectionButton.addTarget(self, action: #selector(collectionTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [captureButton, drawButton, saveButton, collectionButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 12

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(hintLabel)
        contentView.addSubview(previewImageView)
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

            hintLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            previewImageView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 16),
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            previewImageView.heightAnchor.constraint(equalTo: previewImageView.widthAnchor),

            buttonStack.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 20),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    @objc private func captureTapped() {
        #if targetEnvironment(simulator)
        presentPhotoPicker()
        return
        #else
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = true
            picker.delegate = self
            present(picker, animated: true)
            return
        }

        presentPhotoPicker()
        return
        #endif

        showAlert(title: "写真が選べません", message: "この端末ではカメラも写真ライブラリも利用できません。")
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
            let stickerImage = makeStickerImage(from: image)
            pendingStickerImage = stickerImage
            previewImageView.image = stickerImage
            saveButton.isEnabled = true
        }
        navigationController?.pushViewController(drawVC, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let pickedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        if let pickedImage {
            let stickerImage = makeStickerImage(from: pickedImage)
            pendingStickerImage = stickerImage
            previewImageView.image = stickerImage
            saveButton.isEnabled = true
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
                    let stickerImage = self?.makeStickerImage(from: image)
                    self?.pendingStickerImage = stickerImage
                    self?.previewImageView.image = stickerImage
                    self?.saveButton.isEnabled = true
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
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
