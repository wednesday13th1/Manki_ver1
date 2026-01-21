//
//  FlipViewController.swift　.. Flip card
//  manki
//
//  Created by 井上　希稟 on 2026/01/17.
//

import UIKit

class FlipViewController: UIViewController {

    private let savedWordsFileName = "saved_words.json"
    private var words: [SavedWord] = []
    private var currentIndex = 0
    private var isFlipped = false

    private let cardContainer = UIView()
    private let frontView = UIView()
    private let backView = UIView()
    private let frontLabel = UILabel()
    private let backLabel = UILabel()
    private let backStack = UIStackView()
    private let backImageView = UIImageView()
    private let fallbackPlaceholderView = UIView()
    private let retryButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let buttonStack = UIStackView()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var currentRequestID: UUID?
    private var imageTask: URLSessionDataTask?
    private let useLocalComic = false
    private let taskMapFileName = "nanobanana_tasks.json"
    private var taskMap: [String: String] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "フリップ"
        view.backgroundColor = .systemBackground

        configureUI()
        words = loadSavedWords()
        taskMap = loadTaskMap()
        if words.isEmpty {
            showAlert(title: "単語がありません", message: "先に単語を登録してください。")
        }
        showWord()
    }

    private func configureUI() {
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.backgroundColor = .clear
        view.addSubview(cardContainer)

        NSLayoutConstraint.activate([
            cardContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
            cardContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3),
        ])

        [frontView, backView].forEach { cardSide in
            cardSide.translatesAutoresizingMaskIntoConstraints = false
            cardSide.layer.cornerRadius = 16
            cardSide.layer.borderWidth = 1
            cardSide.layer.borderColor = UIColor.systemGray4.cgColor
            cardSide.backgroundColor = .systemBackground
            cardContainer.addSubview(cardSide)
            NSLayoutConstraint.activate([
                cardSide.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
                cardSide.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
                cardSide.topAnchor.constraint(equalTo: cardContainer.topAnchor),
                cardSide.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            ])
        }

        frontLabel.translatesAutoresizingMaskIntoConstraints = false
        frontLabel.font = .systemFont(ofSize: 28, weight: .bold)
        frontLabel.numberOfLines = 0
        frontLabel.textAlignment = .center
        frontView.addSubview(frontLabel)

        backLabel.translatesAutoresizingMaskIntoConstraints = false
        backLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        backLabel.numberOfLines = 0
        backLabel.textAlignment = .center
        backImageView.translatesAutoresizingMaskIntoConstraints = false
        backImageView.contentMode = .scaleAspectFit
        backImageView.clipsToBounds = true
        fallbackPlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        fallbackPlaceholderView.backgroundColor = .systemGray5
        fallbackPlaceholderView.layer.cornerRadius = 12
        fallbackPlaceholderView.clipsToBounds = true
        fallbackPlaceholderView.isHidden = true
        let retryImage = UIImage(systemName: "arrow.trianglehead.2.clockwise")
            ?? UIImage(systemName: "arrow.clockwise")
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setImage(retryImage, for: .normal)
        retryButton.tintColor = .label
        retryButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold),
            forImageIn: .normal
        )
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        retryButton.accessibilityLabel = "画像を再生成"
        retryButton.addTarget(self, action: #selector(retryComicImage), for: .touchUpInside)

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textColor = .secondaryLabel
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        backStack.axis = .vertical
        backStack.spacing = 12
        backStack.translatesAutoresizingMaskIntoConstraints = false
        backView.addSubview(backStack)
        backStack.addArrangedSubview(fallbackPlaceholderView)
        backStack.addArrangedSubview(backImageView)
        backStack.addArrangedSubview(backLabel)
        backStack.addArrangedSubview(errorLabel)
        view.addSubview(retryButton)

        NSLayoutConstraint.activate([
            frontLabel.leadingAnchor.constraint(equalTo: frontView.leadingAnchor, constant: 16),
            frontLabel.trailingAnchor.constraint(equalTo: frontView.trailingAnchor, constant: -16),
            frontLabel.centerYAnchor.constraint(equalTo: frontView.centerYAnchor),
            backStack.leadingAnchor.constraint(equalTo: backView.leadingAnchor, constant: 16),
            backStack.trailingAnchor.constraint(equalTo: backView.trailingAnchor, constant: -16),
            backStack.topAnchor.constraint(equalTo: backView.topAnchor, constant: 16),
            backStack.bottomAnchor.constraint(equalTo: backView.bottomAnchor, constant: -16),
            fallbackPlaceholderView.heightAnchor.constraint(equalTo: backView.heightAnchor, multiplier: 0.6),
            backImageView.heightAnchor.constraint(equalTo: backView.heightAnchor, multiplier: 0.6),
        ])
        NSLayoutConstraint.activate([
            retryButton.leadingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: 8),
            retryButton.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            retryButton.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
        ])

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        backView.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: backView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: backView.centerYAnchor),
        ])

        backView.isHidden = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(flipCard))
        cardContainer.addGestureRecognizer(tapGesture)

        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        prevButton.setTitle("前の単語", for: .normal)
        prevButton.addTarget(self, action: #selector(showPrevWord), for: .touchUpInside)
        buttonStack.addArrangedSubview(prevButton)

        nextButton.setTitle("次の単語", for: .normal)
        nextButton.addTarget(self, action: #selector(showNextWord), for: .touchUpInside)
        buttonStack.addArrangedSubview(nextButton)

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: 24),
            buttonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonStack.widthAnchor.constraint(equalTo: cardContainer.widthAnchor),
        ])
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
        return []
    }

    private func showWord() {
        guard !words.isEmpty else {
            frontLabel.text = "単語がありません"
            backLabel.text = ""
            backImageView.image = nil
            backImageView.isHidden = true
            fallbackPlaceholderView.isHidden = true
            retryButton.isHidden = true
            errorLabel.text = ""
            loadingIndicator.stopAnimating()
            prevButton.isEnabled = false
            nextButton.isEnabled = false
            return
        }
        let word = words[currentIndex]
        frontLabel.text = word.english
        backLabel.text = word.japanese
        loadComicImage(for: word)
        setCardSide(isFront: true, animated: false)
    }

    private func setCardSide(isFront: Bool, animated: Bool) {
        let fromView = isFront ? backView : frontView
        let toView = isFront ? frontView : backView
        let options: UIView.AnimationOptions = isFront ? .transitionFlipFromLeft : .transitionFlipFromRight
        if animated {
            UIView.transition(from: fromView,
                              to: toView,
                              duration: 0.5,
                              options: [options, .showHideTransitionViews])
        } else {
            fromView.isHidden = true
            toView.isHidden = false
        }
        isFlipped = !isFront
    }

    @objc private func flipCard() {
        guard !words.isEmpty else { return }
        setCardSide(isFront: isFlipped, animated: true)
    }

    @objc private func showNextWord() {
        guard !words.isEmpty else { return }
        let nextIndex = currentIndex + 1
        if nextIndex >= words.count {
            currentIndex = 0
            showAlert(title: "お疲れさま！", message: "全ての単語を一周しました！")
        } else {
            currentIndex = nextIndex
        }
        showWord()
    }

    @objc private func showPrevWord() {
        guard !words.isEmpty else { return }
        if currentIndex == 0 {
            currentIndex = words.count - 1
        } else {
            currentIndex -= 1
        }
        showWord()
    }

    private func loadComicImage(for word: SavedWord) {
        errorLabel.text = ""

        if let cached = loadCachedComicImage(for: word) {
            showComicImage(cached)
            loadingIndicator.stopAnimating()
            return
        }

        showComicPlaceholder()
        loadingIndicator.stopAnimating()
        errorLabel.text = "画像が未生成です"
        retryButton.isHidden = false
    }

    private func generateComicImage(for word: SavedWord,
                                    completion: @escaping (Result<Data, ComicError>) -> Void) {
        guard let apiKey = loadComicAPIKey(), !apiKey.isEmpty else {
            completion(.failure(.missingAPIKey))
            return
        }

        guard let callbackURL = loadCallbackURL(), !callbackURL.isEmpty else {
            completion(.failure(.missingCallbackURL))
            return
        }

        guard let resultToken = loadResultToken(), !resultToken.isEmpty else {
            completion(.failure(.missingResultToken))
            return
        }

        let prompt = """
        Draw a two-panel black-and-white manga (2 panels side by side). The word is "\(word.english)" meaning "\(word.japanese)". Panel 1: setup scene. Panel 2: clear payoff that explains the meaning. No text, no speech bubbles, no letters. Simple line art, clean white background, thick outlines, easy to understand. Scenario hint: \(word.illustrationScenario ?? "none").
        """

        if let taskId = taskMap[word.english] {
            pollNanoBananaResult(taskId: taskId, token: resultToken, completion: completion)
            return
        }

        let requestBody = NanoBananaGenerateRequest(type: "TEXTTOIMAGE",
                                                    prompt: prompt,
                                                    numImages: 1,
                                                    imageSize: "4:3",
                                                    callBackUrl: callbackURL)

        guard let url = URL(string: "https://api.nanobananaapi.ai/api/v1/nanobanana/generate") else {
            completion(.failure(.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(requestBody)

        imageTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                print("Comic API error: \(error.localizedDescription)")
                completion(.failure(.requestFailed(error.localizedDescription)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Comic API error: invalid response")
                completion(.failure(.invalidResponse))
                return
            }
            guard let data else {
                print("Comic API error: empty response")
                completion(.failure(.emptyResponse))
                return
            }
            let bodyPreview = String(data: data.prefix(1200), encoding: .utf8) ?? "<non-utf8>"
            print("Comic API status: \(httpResponse.statusCode), bytes: \(data.count)")
            print("Comic API body preview: \(bodyPreview)")
            if httpResponse.statusCode != 200 {
                let message = Self.decodeNanoBananaErrorMessage(data)
                completion(.failure(.httpError(status: httpResponse.statusCode, message: message)))
                return
            }
            guard let taskId = Self.decodeNanoBananaTaskId(data) else {
                completion(.failure(.noImageData))
                return
            }
            self.taskMap[word.english] = taskId
            self.saveTaskMap()
            self.pollNanoBananaResult(taskId: taskId, token: resultToken, completion: completion)
        }
        imageTask?.resume()
    }

    private func loadComicAPIKey() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "NanoBananaAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadCallbackURL() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "NanoBananaCallbackURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadResultToken() -> String? {
        return (Bundle.main.object(forInfoDictionaryKey: "NanoBananaResultToken") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadTaskMap() -> [String: String] {
        let url = taskMapFileURL()
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func saveTaskMap() {
        let url = taskMapFileURL()
        guard let data = try? JSONEncoder().encode(taskMap) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func taskMapFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(taskMapFileName)
    }

    private func loadCachedComicImage(for word: SavedWord) -> UIImage? {
        let url = comicFileURL(for: word)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func saveComicImage(_ data: Data, for word: SavedWord) {
        let url = comicFileURL(for: word)
        try? data.write(to: url, options: .atomic)
    }

    private func comicFileURL(for word: SavedWord) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let safeName = sanitizeFileName(word.english)
        return documents.appendingPathComponent("comic_\(safeName).png")
    }

    private func sanitizeFileName(_ text: String) -> String {
        let pattern = "[^A-Za-z0-9_-]"
        return text.replacingOccurrences(of: pattern, with: "_", options: .regularExpression)
    }

    private func showComicImage(_ image: UIImage) {
        fallbackPlaceholderView.isHidden = true
        backImageView.isHidden = false
        backImageView.image = image
        retryButton.isHidden = false
        retryButton.isEnabled = true
        errorLabel.text = ""
    }

    private func showComicPlaceholder() {
        backImageView.image = nil
        backImageView.isHidden = true
        fallbackPlaceholderView.isHidden = false
    }

    @objc private func retryComicImage() {
        guard !words.isEmpty else { return }
        let word = words[currentIndex]
        currentRequestID = UUID()
        let requestID = currentRequestID
        imageTask?.cancel()
        errorLabel.text = ""
        retryButton.isEnabled = false
        loadingIndicator.startAnimating()
        generateComicImage(for: word) { [weak self] result in
            guard let self else { return }
            guard self.currentRequestID == requestID else { return }
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                self.retryButton.isEnabled = true
                switch result {
                case .success(let data):
                    if let image = UIImage(data: data) {
                        self.showComicImage(image)
                        self.saveComicImage(data, for: word)
                    } else {
                        self.showComicPlaceholder()
                        self.errorLabel.text = "画像データの変換に失敗しました"
                    }
                case .failure(let error):
                    self.showComicPlaceholder()
                    self.errorLabel.text = error.localizedDescription
                }
            }
        }
    }

    private static func decodeNanoBananaTaskId(_ data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(NanoBananaTaskResponse.self, from: data)
        return decoded?.data?.taskId
    }

    private static func decodeNanoBananaErrorMessage(_ data: Data) -> String? {
        let decoded = try? JSONDecoder().decode(NanoBananaErrorResponse.self, from: data)
        return decoded?.message ?? decoded?.msg
    }

    private func pollNanoBananaResult(taskId: String,
                                      token: String,
                                      completion: @escaping (Result<Data, ComicError>) -> Void) {
        let maxAttempts = 12
        let delaySeconds: TimeInterval = 2.0

        func attempt(_ count: Int) {
            guard count < maxAttempts else {
                completion(.failure(.noImageData))
                return
            }
            guard var components = URLComponents(string: "https://nanobanana-webhook.inkit98713.workers.dev/result") else {
                completion(.failure(.invalidURL))
                return
            }
            components.queryItems = [
                URLQueryItem(name: "taskId", value: taskId),
                URLQueryItem(name: "token", value: token),
            ]
            guard let url = components.url else {
                completion(.failure(.invalidURL))
                return
            }
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error {
                    completion(.failure(.requestFailed(error.localizedDescription)))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                guard let data else {
                    completion(.failure(.emptyResponse))
                    return
                }
                if httpResponse.statusCode != 200 {
                    completion(.failure(.httpError(status: httpResponse.statusCode, message: nil)))
                    return
                }
                guard let decoded = try? JSONDecoder().decode(NanoBananaResultResponse.self, from: data) else {
                    completion(.failure(.noImageData))
                    return
                }
                switch decoded.status {
                case "PENDING", "RUNNING":
                    DispatchQueue.global().asyncAfter(deadline: .now() + delaySeconds) {
                        attempt(count + 1)
                    }
                case "SUCCEEDED":
                    guard let imageUrl = decoded.results?.first?.imageUrl,
                          let downloadURL = URL(string: imageUrl) else {
                        completion(.failure(.noImageData))
                        return
                    }
                    URLSession.shared.dataTask(with: downloadURL) { imageData, _, imageError in
                        if let imageError {
                            completion(.failure(.requestFailed(imageError.localizedDescription)))
                            return
                        }
                        guard let imageData else {
                            completion(.failure(.emptyResponse))
                            return
                        }
                        completion(.success(imageData))
                    }.resume()
                default:
                    completion(.failure(.noImageData))
                }
            }.resume()
        }

        attempt(0)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func generateLocalComicImage(for word: SavedWord) -> UIImage? {
        let size = CGSize(width: 700, height: 420)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let padding: CGFloat = 20
            let gutter: CGFloat = 16
            let panelWidth = (size.width - padding * 2 - gutter) / 2
            let panelHeight = size.height - padding * 2
            let leftPanel = CGRect(x: padding, y: padding, width: panelWidth, height: panelHeight)
            let rightPanel = CGRect(x: padding + panelWidth + gutter, y: padding, width: panelWidth, height: panelHeight)

            UIColor.white.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            UIColor.black.setStroke()
            cg.setLineWidth(3)
            cg.stroke(leftPanel)
            cg.stroke(rightPanel)

            let mood = inferMood(for: word)
            drawPanel(in: leftPanel, mood: mood, style: .setup, word: word, context: cg)
            drawPanel(in: rightPanel, mood: mood, style: .punchline, word: word, context: cg)
        }
    }

    private enum Mood {
        case happy
        case sad
        case angry
        case calm
        case neutral
    }

    private enum PanelStyle {
        case setup
        case punchline
    }

    private func inferMood(for word: SavedWord) -> Mood {
        let text = "\(word.english) \(word.japanese) \(word.illustrationScenario ?? "")".lowercased()
        if text.contains("happy") || text.contains("joy") || text.contains("love") || text.contains("kind") || text.contains("benevolent") || text.contains("嬉") || text.contains("幸") || text.contains("優") || text.contains("楽") {
            return .happy
        }
        if text.contains("sad") || text.contains("fear") || text.contains("tired") || text.contains("悲") || text.contains("寂") || text.contains("不安") {
            return .sad
        }
        if text.contains("angry") || text.contains("rage") || text.contains("怒") || text.contains("苛") {
            return .angry
        }
        if text.contains("calm") || text.contains("quiet") || text.contains("静") || text.contains("落ち着") {
            return .calm
        }
        return .neutral
    }

    private enum Scene {
        case kindness
        case study
        case bubble
        case sunset
        case rain
        case music
        case chance
        case respect
        case bias
        case honesty
        case headache
        case conviction
        case curiosity
        case hamburger
        case bird
        case none
    }

    private func inferScene(for word: SavedWord) -> Scene {
        let text = "\(word.english) \(word.japanese) \(word.illustrationScenario ?? "")".lowercased()
        if text.contains("kind") || text.contains("benevolent") || text.contains("優") || text.contains("親切") {
            return .kindness
        }
        if text.contains("study") || text.contains("diligent") || text.contains("勉強") || text.contains("努力") {
            return .study
        }
        if text.contains("bubble") || text.contains("ephemeral") || text.contains("シャボン") || text.contains("はかない") {
            return .bubble
        }
        if text.contains("sunset") || text.contains("夕日") || text.contains("黄昏") {
            return .sunset
        }
        if text.contains("rain") || text.contains("umbrella") || text.contains("雨") || text.contains("傘") {
            return .rain
        }
        if text.contains("music") || text.contains("sound") || text.contains("騒音") || text.contains("音") {
            return .music
        }
        if text.contains("chance") || text.contains("accident") || text.contains("偶然") || text.contains("たまたま") {
            return .chance
        }
        if text.contains("respect") || text.contains("敬意") || text.contains("尊重") || text.contains("礼") {
            return .respect
        }
        if text.contains("bias") || text.contains("偏") || text.contains("先入観") {
            return .bias
        }
        if text.contains("honest") || text.contains("honestly") || text.contains("正直") || text.contains("誠実") {
            return .honesty
        }
        if text.contains("headache") || text.contains("頭痛") {
            return .headache
        }
        if text.contains("確信") || text.contains("conviction") || text.contains("confident") {
            return .conviction
        }
        if text.contains("curious") || text.contains("curiosity") || text.contains("好奇心") {
            return .curiosity
        }
        if text.contains("hamburger") || text.contains("ハンバーガー") {
            return .hamburger
        }
        if text.contains("bird") || text.contains("鳥") {
            return .bird
        }
        return .none
    }

    private func shouldDrawPerson(for word: SavedWord, scene: Scene) -> Bool {
        let text = "\(word.english) \(word.japanese) \(word.illustrationScenario ?? "")".lowercased()
        if text.contains("umbrella") || text.contains("傘") {
            return false
        }
        if text.contains("hamburger") || text.contains("ハンバーガー") {
            return false
        }
        if text.contains("bird") || text.contains("鳥") {
            return false
        }
        switch scene {
        case .sunset, .bubble, .music, .chance, .hamburger, .bird:
            return false
        default:
            return true
        }
    }

    private func drawPanel(in rect: CGRect,
                           mood: Mood,
                           style: PanelStyle,
                           word: SavedWord,
                           context: CGContext) {
        let lineWidth: CGFloat = 3
        context.setLineWidth(lineWidth)
        UIColor.black.setStroke()
        UIColor.black.setFill()

        let scene = inferScene(for: word)
        let drawPerson = shouldDrawPerson(for: word, scene: scene)
        if drawPerson {
            let figureX = rect.midX
            let headRadius: CGFloat = min(rect.width, rect.height) * 0.12
            let headCenter = CGPoint(x: figureX, y: rect.minY + headRadius + 22)
            context.addEllipse(in: CGRect(x: headCenter.x - headRadius,
                                          y: headCenter.y - headRadius,
                                          width: headRadius * 2,
                                          height: headRadius * 2))
            context.strokePath()

            let bodyTop = CGPoint(x: figureX, y: headCenter.y + headRadius)
            let bodyBottom = CGPoint(x: figureX, y: bodyTop.y + rect.height * 0.28)
            context.move(to: bodyTop)
            context.addLine(to: bodyBottom)
            context.strokePath()

            let armY = bodyTop.y + rect.height * 0.08
            context.move(to: CGPoint(x: figureX - rect.width * 0.18, y: armY))
            context.addLine(to: CGPoint(x: figureX + rect.width * 0.18, y: armY))
            context.strokePath()

            context.move(to: bodyBottom)
            context.addLine(to: CGPoint(x: figureX - rect.width * 0.12, y: bodyBottom.y + rect.height * 0.18))
            context.move(to: bodyBottom)
            context.addLine(to: CGPoint(x: figureX + rect.width * 0.12, y: bodyBottom.y + rect.height * 0.18))
            context.strokePath()

            drawFace(mood: mood, center: headCenter, radius: headRadius, context: context)
        }
        drawSceneProp(in: rect, scene: scene, style: style, context: context)

        if style == .setup {
            drawThoughtBubble(in: rect, context: context)
        } else {
            drawActionLines(in: rect, mood: mood, context: context)
        }
    }

    private func drawFace(mood: Mood, center: CGPoint, radius: CGFloat, context: CGContext) {
        let eyeOffsetX = radius * 0.35
        let eyeOffsetY = radius * -0.2
        let eyeRadius = radius * 0.08
        let leftEye = CGRect(x: center.x - eyeOffsetX - eyeRadius,
                             y: center.y + eyeOffsetY - eyeRadius,
                             width: eyeRadius * 2,
                             height: eyeRadius * 2)
        let rightEye = CGRect(x: center.x + eyeOffsetX - eyeRadius,
                              y: center.y + eyeOffsetY - eyeRadius,
                              width: eyeRadius * 2,
                              height: eyeRadius * 2)
        context.addEllipse(in: leftEye)
        context.addEllipse(in: rightEye)
        context.fillPath()

        let mouthWidth = radius * 0.7
        let mouthY = center.y + radius * 0.3
        let mouthRect = CGRect(x: center.x - mouthWidth / 2,
                               y: mouthY,
                               width: mouthWidth,
                               height: radius * 0.4)
        switch mood {
        case .happy:
            context.addArc(center: CGPoint(x: mouthRect.midX, y: mouthRect.minY),
                           radius: mouthWidth / 2,
                           startAngle: 0,
                           endAngle: .pi,
                           clockwise: false)
        case .sad:
            context.addArc(center: CGPoint(x: mouthRect.midX, y: mouthRect.maxY),
                           radius: mouthWidth / 2,
                           startAngle: .pi,
                           endAngle: 0,
                           clockwise: false)
        case .angry:
            context.move(to: CGPoint(x: mouthRect.minX, y: mouthRect.midY))
            context.addLine(to: CGPoint(x: mouthRect.maxX, y: mouthRect.midY))
            drawAngryEyebrows(center: center, radius: radius, context: context)
        case .calm, .neutral:
            context.move(to: CGPoint(x: mouthRect.minX, y: mouthRect.midY))
            context.addLine(to: CGPoint(x: mouthRect.maxX, y: mouthRect.midY))
        }
        context.strokePath()
    }

    private func drawAngryEyebrows(center: CGPoint, radius: CGFloat, context: CGContext) {
        let offsetY = radius * -0.45
        let length = radius * 0.35
        context.move(to: CGPoint(x: center.x - radius * 0.45, y: center.y + offsetY))
        context.addLine(to: CGPoint(x: center.x - radius * 0.1, y: center.y + offsetY + length * 0.3))
        context.move(to: CGPoint(x: center.x + radius * 0.45, y: center.y + offsetY))
        context.addLine(to: CGPoint(x: center.x + radius * 0.1, y: center.y + offsetY + length * 0.3))
        context.strokePath()
    }

    private func drawThoughtBubble(in rect: CGRect, context: CGContext) {
        let bubbleRadius = rect.width * 0.12
        let bubbleCenter = CGPoint(x: rect.maxX - bubbleRadius - 16,
                                   y: rect.minY + bubbleRadius + 24)
        context.addEllipse(in: CGRect(x: bubbleCenter.x - bubbleRadius,
                                      y: bubbleCenter.y - bubbleRadius,
                                      width: bubbleRadius * 2,
                                      height: bubbleRadius * 2))
        context.strokePath()

        let smallRadius = bubbleRadius * 0.3
        context.addEllipse(in: CGRect(x: bubbleCenter.x - bubbleRadius - smallRadius * 1.6,
                                      y: bubbleCenter.y + bubbleRadius * 0.7,
                                      width: smallRadius * 2,
                                      height: smallRadius * 2))
        context.strokePath()
    }

    private func drawActionLines(in rect: CGRect, mood: Mood, context: CGContext) {
        guard mood == .happy || mood == .angry else { return }
        let startX = rect.minX + rect.width * 0.1
        let endX = rect.minX + rect.width * 0.3
        let baseY = rect.maxY - rect.height * 0.15
        for i in 0..<3 {
            let y = baseY - CGFloat(i) * 8
            context.move(to: CGPoint(x: startX, y: y))
            context.addLine(to: CGPoint(x: endX, y: y))
        }
        context.strokePath()
    }

    private func drawSceneProp(in rect: CGRect, scene: Scene, style: PanelStyle, context: CGContext) {
        switch scene {
        case .kindness:
            drawUmbrella(in: rect, context: context)
        case .study:
            drawBook(in: rect, context: context)
        case .bubble:
            drawBubbles(in: rect, context: context)
        case .sunset:
            drawSun(in: rect, context: context)
        case .rain:
            drawUmbrella(in: rect, context: context)
        case .music:
            drawSoundWaves(in: rect, context: context)
        case .chance:
            drawDice(in: rect, context: context)
        case .respect:
            drawBow(in: rect, context: context)
        case .bias:
            drawScale(in: rect, context: context)
        case .honesty:
            drawOpenHeart(in: rect, context: context)
        case .headache:
            drawHeadacheLines(in: rect, context: context)
        case .conviction:
            drawFlag(in: rect, context: context)
        case .curiosity:
            drawMagnifyingGlass(in: rect, context: context)
        case .hamburger:
            drawHamburger(in: rect, context: context)
        case .bird:
            drawBird(in: rect, context: context)
        case .none:
            break
        }
    }

    private func drawUmbrella(in rect: CGRect, context: CGContext) {
        let width = rect.width * 0.28
        let height = rect.height * 0.12
        let origin = CGPoint(x: rect.minX + rect.width * 0.1, y: rect.maxY - rect.height * 0.28)
        let arcCenter = CGPoint(x: origin.x + width / 2, y: origin.y + height / 2)
        context.addArc(center: arcCenter, radius: width / 2, startAngle: .pi, endAngle: 0, clockwise: false)
        context.strokePath()
        context.move(to: CGPoint(x: arcCenter.x, y: arcCenter.y + height / 2))
        context.addLine(to: CGPoint(x: arcCenter.x, y: arcCenter.y + height / 2 + rect.height * 0.12))
        context.strokePath()
    }

    private func drawBook(in rect: CGRect, context: CGContext) {
        let bookRect = CGRect(x: rect.maxX - rect.width * 0.32,
                              y: rect.maxY - rect.height * 0.3,
                              width: rect.width * 0.22,
                              height: rect.height * 0.16)
        context.stroke(bookRect)
        context.move(to: CGPoint(x: bookRect.midX, y: bookRect.minY))
        context.addLine(to: CGPoint(x: bookRect.midX, y: bookRect.maxY))
        context.strokePath()
    }

    private func drawBubbles(in rect: CGRect, context: CGContext) {
        let base = CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.25)
        for i in 0..<3 {
            let r = rect.width * (0.03 + CGFloat(i) * 0.01)
            let offset = CGFloat(i) * 18
            let bubble = CGRect(x: base.x + offset,
                                y: base.y + offset,
                                width: r * 2,
                                height: r * 2)
            context.strokeEllipse(in: bubble)
        }
    }

    private func drawSun(in rect: CGRect, context: CGContext) {
        let radius = rect.width * 0.08
        let center = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.22)
        context.strokeEllipse(in: CGRect(x: center.x - radius,
                                         y: center.y - radius,
                                         width: radius * 2,
                                         height: radius * 2))
        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3)
            let start = CGPoint(x: center.x + cos(angle) * (radius + 6),
                                y: center.y + sin(angle) * (radius + 6))
            let end = CGPoint(x: center.x + cos(angle) * (radius + 16),
                              y: center.y + sin(angle) * (radius + 16))
            context.move(to: start)
            context.addLine(to: end)
        }
        context.strokePath()
    }

    private func drawSoundWaves(in rect: CGRect, context: CGContext) {
        let startX = rect.minX + rect.width * 0.1
        let baseY = rect.minY + rect.height * 0.18
        for i in 0..<3 {
            let radius = rect.width * (0.05 + CGFloat(i) * 0.03)
            let center = CGPoint(x: startX, y: baseY)
            context.addArc(center: center,
                           radius: radius,
                           startAngle: -.pi / 4,
                           endAngle: .pi / 4,
                           clockwise: false)
        }
        context.strokePath()
    }

    private func drawDice(in rect: CGRect, context: CGContext) {
        let size = rect.width * 0.14
        let origin = CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.28)
        let dice = CGRect(x: origin.x, y: origin.y, width: size, height: size)
        context.stroke(dice)
        let pipRadius = size * 0.08
        let pips = [
            CGPoint(x: dice.midX, y: dice.midY),
            CGPoint(x: dice.minX + size * 0.25, y: dice.minY + size * 0.25),
            CGPoint(x: dice.maxX - size * 0.25, y: dice.maxY - size * 0.25),
        ]
        for pip in pips {
            context.fillEllipse(in: CGRect(x: pip.x - pipRadius,
                                           y: pip.y - pipRadius,
                                           width: pipRadius * 2,
                                           height: pipRadius * 2))
        }
    }

    private func drawBow(in rect: CGRect, context: CGContext) {
        let headRadius = rect.width * 0.04
        let bodyTop = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.35)
        context.strokeEllipse(in: CGRect(x: bodyTop.x - headRadius,
                                         y: bodyTop.y - headRadius * 2,
                                         width: headRadius * 2,
                                         height: headRadius * 2))
        context.move(to: CGPoint(x: bodyTop.x, y: bodyTop.y))
        context.addLine(to: CGPoint(x: bodyTop.x + rect.width * 0.08, y: bodyTop.y + rect.height * 0.12))
        context.strokePath()
    }

    private func drawScale(in rect: CGRect, context: CGContext) {
        let baseY = rect.maxY - rect.height * 0.2
        let centerX = rect.minX + rect.width * 0.18
        context.move(to: CGPoint(x: centerX, y: baseY))
        context.addLine(to: CGPoint(x: centerX, y: baseY - rect.height * 0.18))
        context.strokePath()
        context.move(to: CGPoint(x: centerX - rect.width * 0.08, y: baseY - rect.height * 0.18))
        context.addLine(to: CGPoint(x: centerX + rect.width * 0.1, y: baseY - rect.height * 0.16))
        context.strokePath()
        context.strokeEllipse(in: CGRect(x: centerX - rect.width * 0.12,
                                         y: baseY - rect.height * 0.1,
                                         width: rect.width * 0.08,
                                         height: rect.width * 0.04))
        context.strokeEllipse(in: CGRect(x: centerX + rect.width * 0.06,
                                         y: baseY - rect.height * 0.08,
                                         width: rect.width * 0.08,
                                         height: rect.width * 0.04))
    }

    private func drawOpenHeart(in rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.22)
        let size = rect.width * 0.07
        let left = CGRect(x: center.x - size, y: center.y - size, width: size, height: size)
        let right = CGRect(x: center.x, y: center.y - size, width: size, height: size)
        context.strokeEllipse(in: left)
        context.strokeEllipse(in: right)
        context.move(to: CGPoint(x: center.x - size, y: center.y))
        context.addLine(to: CGPoint(x: center.x, y: center.y + size * 1.4))
        context.addLine(to: CGPoint(x: center.x + size, y: center.y))
        context.strokePath()
    }

    private func drawHeadacheLines(in rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.2)
        for i in 0..<3 {
            let offset = CGFloat(i) * 8
            context.move(to: CGPoint(x: center.x - 10, y: center.y + offset))
            context.addLine(to: CGPoint(x: center.x + 10, y: center.y + offset + 6))
        }
        context.strokePath()
    }

    private func drawFlag(in rect: CGRect, context: CGContext) {
        let poleX = rect.minX + rect.width * 0.14
        let topY = rect.minY + rect.height * 0.18
        let bottomY = rect.minY + rect.height * 0.42
        context.move(to: CGPoint(x: poleX, y: bottomY))
        context.addLine(to: CGPoint(x: poleX, y: topY))
        context.strokePath()
        let flagRect = CGRect(x: poleX, y: topY, width: rect.width * 0.14, height: rect.height * 0.1)
        context.stroke(flagRect)
    }

    private func drawMagnifyingGlass(in rect: CGRect, context: CGContext) {
        let radius = rect.width * 0.06
        let center = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.24)
        context.strokeEllipse(in: CGRect(x: center.x - radius,
                                         y: center.y - radius,
                                         width: radius * 2,
                                         height: radius * 2))
        context.move(to: CGPoint(x: center.x + radius * 0.7, y: center.y + radius * 0.7))
        context.addLine(to: CGPoint(x: center.x + radius * 1.8, y: center.y + radius * 1.8))
        context.strokePath()
    }

    private func drawHamburger(in rect: CGRect, context: CGContext) {
        let centerX = rect.midX
        let baseY = rect.maxY - rect.height * 0.24
        let width = rect.width * 0.35
        let bunHeight = rect.height * 0.06
        let topBun = CGRect(x: centerX - width / 2, y: baseY - bunHeight * 2, width: width, height: bunHeight)
        let bottomBun = CGRect(x: centerX - width / 2, y: baseY, width: width, height: bunHeight)
        context.stroke(topBun)
        context.stroke(bottomBun)
        context.move(to: CGPoint(x: centerX - width / 2, y: baseY - bunHeight))
        context.addLine(to: CGPoint(x: centerX + width / 2, y: baseY - bunHeight))
        context.strokePath()
    }

    private func drawBird(in rect: CGRect, context: CGContext) {
        let center = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.3)
        let radius = rect.width * 0.05
        context.addArc(center: center, radius: radius, startAngle: .pi * 0.2, endAngle: .pi * 1.1, clockwise: false)
        context.addArc(center: CGPoint(x: center.x + radius * 1.6, y: center.y),
                       radius: radius,
                       startAngle: .pi * 0.9,
                       endAngle: .pi * 1.8,
                       clockwise: false)
        context.strokePath()
    }
}

private struct NanoBananaGenerateRequest: Encodable {
    let type: String
    let prompt: String
    let numImages: Int
    let imageSize: String
    let callBackUrl: String

    private enum CodingKeys: String, CodingKey {
        case type
        case prompt
        case numImages
        case imageSize = "image_size"
        case callBackUrl
    }
}

private struct NanoBananaTaskResponse: Decodable {
    struct DataInfo: Decodable {
        let taskId: String?
    }
    let code: Int?
    let msg: String?
    let data: DataInfo?
}

private struct NanoBananaResultResponse: Decodable {
    struct Result: Decodable {
        let imageUrl: String?
    }
    let taskId: String?
    let status: String?
    let results: [Result]?
    let error: String?
}

private struct NanoBananaErrorResponse: Decodable {
    let message: String?
    let msg: String?
}

private enum ComicError: LocalizedError {
    case missingAPIKey
    case missingCallbackURL
    case missingResultToken
    case invalidURL
    case requestFailed(String)
    case invalidResponse
    case emptyResponse
    case httpError(status: Int, message: String?)
    case noImageData

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが未設定です"
        case .missingCallbackURL:
            return "Callback URLが未設定です"
        case .missingResultToken:
            return "結果取得トークンが未設定です"
        case .invalidURL:
            return "API URLが不正です"
        case .requestFailed(let message):
            return "通信に失敗しました: \(message)"
        case .invalidResponse:
            return "不正なレスポンスです"
        case .emptyResponse:
            return "レスポンスが空でした"
        case .httpError(let status, let message):
            if let message, !message.isEmpty {
                return "APIエラー(\(status)): \(message)"
            }
            return "APIエラー(\(status))"
        case .noImageData:
            return "画像データが見つかりません"
        }
    }
}
