//
//  AddViewController.swift
//  manki
//
//  Created by Codex.
//

import UIKit

final class AddViewController: UIViewController {

    @IBOutlet private var englishTextField: UITextField!
    @IBOutlet private var japaneseTextField: UITextField!

    private let generateImageButton = UIButton(type: .system)
    private let importButton = UIButton(type: .system)
    private let previewImageView = UIImageView()

    private struct AIWord: Codable {
        let word: String
        let meaning: String
    }

    private let savedWordsFileName = "saved_words.json"
    private var savedWords: [SavedWord] = []
    private var aiWords: [AIWord] = []
    private var pendingScenario: String?
    private var lastGeneratedEnglish: String?
    private var lastGeneratedJapanese: String?
    private var scenarioTask: URLSessionDataTask?
    private var imageTask: URLSessionDataTask?
    private var pendingImageFileName: String?
    private var lastImageEnglish: String?
    private var lastImageJapanese: String?
    private let imageLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private var pendingImageSource: PendingImageSource?
    private var importOverlay: UIControl?
    private var importContainer: UIView?
    private var importTextView: UITextView?

    private enum PendingImageSource {
        case generated
        case sticker
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        savedWords = loadSavedWords()
        aiWords = loadAIWordsFromBundle()
        englishTextField.addTarget(self, action: #selector(textFieldEdited), for: .editingChanged)
        japaneseTextField.addTarget(self, action: #selector(textFieldEdited), for: .editingChanged)
        configurePreviewImageView()
        configureImportButton()
        applyPixelFonts()
        applyPixelNavigationFonts()
    }

    @objc private func textFieldEdited() {
        pendingScenario = nil
        lastGeneratedEnglish = nil
        lastGeneratedJapanese = nil
        if pendingImageSource == .generated {
            clearPendingImage(removeFile: true)
        }
    }

    @IBAction private func saveWord() {
        let english = englishTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let japanese = japaneseTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !english.isEmpty, !japanese.isEmpty else {
            showAlert(title: "入力エラー", message: "英語と日本語を入力してください。")
            return
        }
        let scenario: String?
        if english == lastGeneratedEnglish, japanese == lastGeneratedJapanese {
            scenario = pendingScenario
        } else {
            scenario = nil
        }
        let imageFileName: String?
        switch pendingImageSource {
        case .sticker:
            imageFileName = pendingImageFileName
        case .generated:
            if english == lastImageEnglish, japanese == lastImageJapanese {
                imageFileName = pendingImageFileName
            } else {
                imageFileName = nil
                clearPendingImage(removeFile: true)
            }
        case .none:
            imageFileName = nil
        }
        savedWords.append(SavedWord(english: english,
                                    japanese: japanese,
                                    illustrationScenario: scenario,
                                    illustrationImageFileName: imageFileName))
        saveSavedWords()
        showAlert(title: "保存しました", message: "単語を追加しました。") { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    @IBAction private func generateAIWord() {
        guard let random = aiWords.randomElement() else {
            showAlert(title: "生成エラー", message: "単語データが見つかりませんでした。")
            return
        }
        englishTextField.text = random.word
        japaneseTextField.text = random.meaning
        lastGeneratedEnglish = random.word
        lastGeneratedJapanese = random.meaning
        pendingScenario = nil
        clearPendingImage(removeFile: true)
        generateIllustrationScenario(english: random.word, japanese: random.meaning)
    }

    @objc private func generateIllustrationImageTapped() {
        let picker = StiCollectViewController()
        picker.selectionHandler = { [weak self] sticker in
            guard let self else { return }
            guard let image = StickerStore.loadStickerImage(fileName: sticker.imageFileName) else {
                self.showAlert(title: "選択エラー", message: "ステッカー画像を読み込めませんでした。")
                return
            }
            self.pendingImageFileName = sticker.imageFileName
            self.pendingImageSource = .sticker
            self.previewImageView.image = image
        }
        let nav = UINavigationController(rootViewController: picker)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func savedWordsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(savedWordsFileName)
    }

    private func loadSavedWords() -> [SavedWord] {
        let fileURL = savedWordsFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            return decoded
        }
        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            savedWords = migrated
            saveSavedWords()
            return migrated
        }
        return []
    }

    private func saveSavedWords() {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(savedWords) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadAIWordsFromBundle() -> [AIWord] {
        guard let fileURL = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        return (try? JSONDecoder().decode([AIWord].self, from: data)) ?? []
    }

    private func showAlert(title: String, message: String, onOK: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            onOK?()
        })
        present(alert, animated: true)
    }

    private func configurePreviewImageView() {
        generateImageButton.translatesAutoresizingMaskIntoConstraints = false
        generateImageButton.setTitle("ステッカーを選ぶ", for: .normal)
        generateImageButton.addTarget(self, action: #selector(generateIllustrationImageTapped), for: .touchUpInside)

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.backgroundColor = UIColor.systemGray6
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.layer.cornerRadius = 8
        previewImageView.clipsToBounds = true

        imageLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        imageLoadingIndicator.hidesWhenStopped = true
        previewImageView.addSubview(imageLoadingIndicator)
        NSLayoutConstraint.activate([
            imageLoadingIndicator.centerXAnchor.constraint(equalTo: previewImageView.centerXAnchor),
            imageLoadingIndicator.centerYAnchor.constraint(equalTo: previewImageView.centerYAnchor),
        ])

        view.addSubview(generateImageButton)
        view.addSubview(previewImageView)

        NSLayoutConstraint.activate([
            generateImageButton.topAnchor.constraint(equalTo: englishTextField.bottomAnchor, constant: 24),
            generateImageButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            generateImageButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            generateImageButton.heightAnchor.constraint(equalToConstant: 44),

            previewImageView.topAnchor.constraint(equalTo: generateImageButton.bottomAnchor, constant: 12),
            previewImageView.leadingAnchor.constraint(equalTo: generateImageButton.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: generateImageButton.trailingAnchor),
        ])

        let previewPreferredHeight = previewImageView.heightAnchor.constraint(equalToConstant: 160)
        previewPreferredHeight.priority = .defaultHigh
        previewPreferredHeight.isActive = true
        let previewMaxHeight = previewImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 180)
        previewMaxHeight.priority = .required
        previewMaxHeight.isActive = true
        let previewMinHeight = previewImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        previewMinHeight.priority = .defaultLow
        previewMinHeight.isActive = true
    }

    private func configureImportButton() {
        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.setTitle("Google Sheet/CSVから追加", for: .normal)
        importButton.addTarget(self, action: #selector(openImportModal), for: .touchUpInside)
        view.addSubview(importButton)

        NSLayoutConstraint.activate([
            importButton.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 14),
            importButton.leadingAnchor.constraint(equalTo: previewImageView.leadingAnchor),
            importButton.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor),
            importButton.heightAnchor.constraint(equalToConstant: 44),
            importButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func applyPixelFonts() {
        applyPixelFontRecursively(to: view)
    }

    private func applyPixelFontRecursively(to view: UIView) {
        if let label = view as? UILabel {
            let size = label.font?.pointSize ?? 17
            label.font = AppFont.jp(size: size)
        } else if let textField = view as? UITextField {
            let size = textField.font?.pointSize ?? 14
            textField.font = AppFont.jp(size: size)
        } else if let button = view as? UIButton, let titleLabel = button.titleLabel {
            let size = titleLabel.font.pointSize
            button.titleLabel?.font = AppFont.jp(size: size)
        } else if let textView = view as? UITextView {
            let size = textView.font?.pointSize ?? 14
            textView.font = AppFont.jp(size: size)
        }

        for subview in view.subviews {
            applyPixelFontRecursively(to: subview)
        }
    }

    private func applyPixelNavigationFonts() {
        navigationController?.navigationBar.titleTextAttributes = [
            .font: AppFont.jp(size: 18, weight: .semibold)
        ]
        let barFont = AppFont.jp(size: 16)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.font: barFont], for: .normal)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.font: barFont], for: .highlighted)
    }

    @objc private func openImportModal() {
        guard importOverlay == nil else { return }
        let overlay = UIControl()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.addTarget(self, action: #selector(dismissImportModal), for: .touchUpInside)
        overlay.accessibilityViewIsModal = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "貼り付けインポート"
        titleLabel.textAlignment = .center
        titleLabel.font = AppFont.jp(size: 16, weight: .bold)

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = AppFont.jp(size: 14)
        textView.layer.borderWidth = 2
        textView.layer.cornerRadius = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)

        let importButton = UIButton(type: .system)
        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.setTitle("読み込み", for: .normal)
        importButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        importButton.addTarget(self, action: #selector(handleImport), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("キャンセル", for: .normal)
        cancelButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        cancelButton.addTarget(self, action: #selector(dismissImportModal), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [importButton, cancelButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 8

        container.addSubview(titleLabel)
        container.addSubview(textView)
        container.addSubview(buttonStack)
        overlay.addSubview(container)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 300),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 180),

            buttonStack.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])

        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor
        container.layer.cornerRadius = 0
        titleLabel.textColor = palette.text
        textView.backgroundColor = palette.surfaceAlt
        textView.textColor = palette.text
        textView.layer.borderColor = palette.border.cgColor
        [importButton, cancelButton].forEach { button in
            button.backgroundColor = palette.surfaceAlt
            button.layer.borderWidth = 2
            button.layer.borderColor = palette.border.cgColor
            button.setTitleColor(palette.text, for: .normal)
            button.layer.cornerRadius = 0
        }

        importOverlay = overlay
        importContainer = container
        importTextView = textView

        overlay.alpha = 0
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            overlay.alpha = 1
            container.alpha = 1
            container.transform = .identity
        }
    }

    @objc private func dismissImportModal() {
        guard let overlay = importOverlay, let container = importContainer else { return }
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            overlay.alpha = 0
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { [weak self] _ in
            overlay.removeFromSuperview()
            self?.importOverlay = nil
            self?.importContainer = nil
            self?.importTextView = nil
        }
    }

    @objc private func handleImport() {
        guard let raw = importTextView?.text, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "入力エラー", message: "シート内容を貼り付けてください。")
            return
        }
        let pairs = parseImportText(raw)
        if pairs.isEmpty {
            showAlert(title: "形式エラー", message: "英語と日本語の2列を貼り付けてください。")
            return
        }
        savedWords = loadSavedWords()
        var added = 0
        var updated = 0
        for (english, japanese) in pairs {
            if let index = savedWords.firstIndex(where: { $0.english.caseInsensitiveCompare(english) == .orderedSame }) {
                let existing = savedWords[index]
                let updatedWord = SavedWord(english: english,
                                            japanese: japanese,
                                            illustrationScenario: existing.illustrationScenario,
                                            illustrationImageFileName: existing.illustrationImageFileName,
                                            isFavorite: existing.isFavorite,
                                            importanceLevel: existing.importanceLevel,
                                            id: existing.id)
                savedWords[index] = updatedWord
                updated += 1
            } else {
                savedWords.append(SavedWord(english: english,
                                            japanese: japanese,
                                            illustrationScenario: nil,
                                            illustrationImageFileName: nil))
                added += 1
            }
        }
        saveSavedWords()
        dismissImportModal()
        showAlert(title: "インポート完了", message: "追加 \(added)件 / 上書き \(updated)件")
    }

    private func parseImportText(_ raw: String) -> [(String, String)] {
        let lines = raw.split(whereSeparator: \.isNewline)
        var results: [(String, String)] = []
        for lineSub in lines {
            let line = String(lineSub).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            let cols: [String]
            if line.contains("\t") {
                cols = line.components(separatedBy: "\t")
            } else {
                cols = line.components(separatedBy: ",")
            }
            guard cols.count >= 2 else { continue }
            let english = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let japanese = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if english.isEmpty || japanese.isEmpty { continue }
            results.append((english, japanese))
        }
        return results
    }

    private func clearPendingImage(removeFile: Bool) {
        imageTask?.cancel()
        if removeFile, let fileName = pendingImageFileName {
            if !stickerFileExists(fileName: fileName) {
                try? FileManager.default.removeItem(at: imageFileURL(fileName: fileName))
            }
        }
        pendingImageFileName = nil
        pendingImageSource = nil
        lastImageEnglish = nil
        lastImageJapanese = nil
        previewImageView.image = nil
        imageLoadingIndicator.stopAnimating()
    }

    private func stickerFileExists(fileName: String) -> Bool {
        let url = StickerStore.stickersDirectoryURL(createIfNeeded: false).appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func generateIllustrationScenario(english: String, japanese: String) {
        scenarioTask?.cancel()
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String,
              !apiKey.isEmpty else {
            showAlert(title: "APIキー未設定", message: "GeminiAPIKeyをInfo.plistに設定してください。")
            return
        }

        let prompt = """
        日本語で「2コマ漫画のシーン指示」を作成してください。英単語: "\(english)"、意味: "\(japanese)"。
        条件:
        - 1コマ目=状況、2コマ目=意味がはっきり伝わる結末
        - 登場物は具体的に(傘、時計、ハンバーガー等)。抽象表現NG
        - 行動が分かる動詞を入れる(渡す/走る/落ちる/見つめる等)
        - セリフ・文字は入れない
        - 25語以内
        出力形式: 「1コマ目: ... / 2コマ目: ...」
        """

        let requestBody = GeminiTextRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ]
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)") else {
            showAlert(title: "生成エラー", message: "API URLが不正です。")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        scenarioTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.showAlert(title: "生成エラー", message: "通信に失敗しました: \(error.localizedDescription)")
                }
                return
            }
            guard let data else {
                DispatchQueue.main.async {
                    self.showAlert(title: "生成エラー", message: "レスポンスが空でした。")
                }
                return
            }
            if let scenario = Self.decodeScenario(from: data) {
                DispatchQueue.main.async {
                    self.pendingScenario = scenario
                }
                return
            }
            DispatchQueue.main.async {
                self.showAlert(title: "生成エラー", message: "シナリオを取得できませんでした。")
            }
        }
        scenarioTask?.resume()
    }

    private func generateIllustrationImage(english: String, japanese: String) {
        imageTask?.cancel()
        clearPendingImage(removeFile: true)
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String,
              !apiKey.isEmpty else {
            showAlert(title: "APIキー未設定", message: "GeminiAPIKeyをInfo.plistに設定してください。")
            return
        }
        let modelName = loadGeminiImageModel()

        let prompt = """
        Create a clean, friendly illustration that represents the English word "\(english)" (Japanese: "\(japanese)"). No text, no letters, no speech bubbles. Simple, centered subject, clear action if needed, white background.
        """

        let requestBody = GeminiImageRequest(
            contents: [
                .init(parts: [.init(text: prompt)])
            ],
            generationConfig: .init(responseModalities: ["IMAGE"])
        )

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)") else {
            showAlert(title: "生成エラー", message: "API URLが不正です。")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        imageLoadingIndicator.startAnimating()
        imageTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.imageLoadingIndicator.stopAnimating()
                    self.showAlert(title: "生成エラー", message: "通信に失敗しました: \(error.localizedDescription)")
                }
                return
            }
            guard let data else {
                DispatchQueue.main.async {
                    self.imageLoadingIndicator.stopAnimating()
                    self.showAlert(title: "生成エラー", message: "レスポンスが空でした。")
                }
                return
            }
            guard let decoded = Self.decodeImageData(from: data) else {
                let apiMessage = Self.decodeGeminiErrorMessage(from: data)
                DispatchQueue.main.async {
                    self.imageLoadingIndicator.stopAnimating()
                    if let apiMessage, !apiMessage.isEmpty {
                        self.showAlert(title: "生成エラー", message: apiMessage)
                    } else {
                        self.showAlert(title: "生成エラー", message: "画像データを取得できませんでした。")
                    }
                }
                return
            }
            guard let image = UIImage(data: decoded.data) else {
                DispatchQueue.main.async {
                    self.imageLoadingIndicator.stopAnimating()
                    self.showAlert(title: "生成エラー", message: "画像データの読み込みに失敗しました。")
                }
                return
            }
            let fileName = self.saveGeneratedImageData(decoded.data, mimeType: decoded.mimeType)
            DispatchQueue.main.async {
                self.imageLoadingIndicator.stopAnimating()
                self.previewImageView.image = image
                if let fileName {
                    self.pendingImageFileName = fileName
                    self.pendingImageSource = .generated
                    self.lastImageEnglish = english
                    self.lastImageJapanese = japanese
                } else {
                    self.showAlert(title: "保存エラー", message: "画像の保存に失敗しました。")
                }
            }
        }
        imageTask?.resume()
    }

    private func imageFileURL(fileName: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }

    private func loadGeminiImageModel() -> String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GeminiImageModel") as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return "gemini-2.0-flash-exp"
    }

    private func saveGeneratedImageData(_ data: Data, mimeType: String?) -> String? {
        let fileExtension: String
        switch mimeType {
        case "image/jpeg":
            fileExtension = "jpg"
        case "image/webp":
            fileExtension = "webp"
        default:
            fileExtension = "png"
        }
        let fileName = "word_image_\(UUID().uuidString).\(fileExtension)"
        let url = imageFileURL(fileName: fileName)
        do {
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    private static func decodeScenario(from data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(GeminiTextResponse.self, from: data)
        let text = decoded?.candidates?.first?.content?.parts?.first?.text
        return text?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeImageData(from data: Data) -> (data: Data, mimeType: String?)? {
        let decoded = try? JSONDecoder().decode(GeminiImageResponse.self, from: data)
        guard let part = decoded?.candidates?.first?.content?.parts?.first(where: { $0.inlineData?.data != nil }) else {
            return nil
        }
        guard let inlineData = part.inlineData, let encoded = inlineData.data else {
            return nil
        }
        guard let imageData = Data(base64Encoded: encoded) else {
            return nil
        }
        return (imageData, inlineData.mimeType)
    }

    private static func decodeGeminiErrorMessage(from data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data)
        return decoded?.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

private struct GeminiTextRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let role: String? = nil
        let parts: [Part]
    }
    let contents: [Content]
}


private struct GeminiTextResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}

private struct GeminiImageRequest: Encodable {
    struct Content: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let role: String? = nil
        let parts: [Part]
    }
    struct GenerationConfig: Encodable {
        let responseModalities: [String]
    }
    let contents: [Content]
    let generationConfig: GenerationConfig
}

private struct GeminiImageResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                struct InlineData: Decodable {
                    let mimeType: String?
                    let data: String?

                    private enum CodingKeys: String, CodingKey {
                        case mimeType
                        case mime_type
                        case data
                    }

                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        let decodedMimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
                            ?? container.decodeIfPresent(String.self, forKey: .mime_type)
                        let decodedData = try container.decodeIfPresent(String.self, forKey: .data)
                        mimeType = decodedMimeType
                        data = decodedData
                    }
                }
                let inlineData: InlineData?
                let text: String?

                private enum CodingKeys: String, CodingKey {
                    case inlineData
                    case inline_data
                    case text
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let decodedInlineData = try container.decodeIfPresent(InlineData.self, forKey: .inlineData)
                        ?? container.decodeIfPresent(InlineData.self, forKey: .inline_data)
                    inlineData = decodedInlineData
                    text = try container.decodeIfPresent(String.self, forKey: .text)
                }
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}

private struct GeminiErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let message: String?
    }
    let error: ErrorDetail?
}
