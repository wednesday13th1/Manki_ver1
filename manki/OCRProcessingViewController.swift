import UIKit
import Vision

final class OCRProcessingViewController: UIViewController {
    private let image: UIImage
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)

    // ImportPreviewVC で確定した rows を AddVC へ返す
    var onConfirmRows: (([ImportRow]) -> Void)?

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "OCR処理"
        view.backgroundColor = .systemBackground
        configureUI()
        runOCR()
    }

    private func configureUI() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "文字認識中..."
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = AppFont.jp(size: 14)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        view.addSubview(statusLabel)
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -16)
        ])
    }

    private func runOCR() {
        // Vision OCR の最小実装
        guard let cgImage = image.cgImage else {
            showError("画像の読み込みに失敗しました")
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, _ in
            guard let self else { return }
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let lines = Self.buildLinesWithTwoColumnDetection(observations)
            DispatchQueue.main.async {
                self.handleOCR(lines: lines)
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "ja-JP"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.showError("OCRに失敗しました")
                }
            }
        }
    }

    private func handleOCR(lines: [String]) {
        spinner.stopAnimating()
        let rawText = lines.joined(separator: "\n")
        if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showError("文字が検出できませんでした")
            return
        }
        // パース後に編集画面へ遷移
        let rows = ImportParser.parse(text: rawText, mode: .auto)
        let session = ImportSession(sourceText: rawText, rows: rows)
        let preview = ImportPreviewViewController(session: session)
        preview.onConfirm = { [weak self] rows in
            guard let self else { return }
            self.onConfirmRows?(rows)
            if let nav = self.navigationController {
                if let addVC = nav.viewControllers.first(where: { $0 is AddViewController }) {
                    nav.popToViewController(addVC, animated: true)
                } else {
                    nav.popToRootViewController(animated: true)
                }
            }
        }
        navigationController?.pushViewController(preview, animated: true)
    }

    private func showError(_ message: String) {
        spinner.stopAnimating()
        let alert = UIAlertController(title: "OCRエラー", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

private extension OCRProcessingViewController {
    struct OCRLine {
        let text: String
        let bbox: CGRect
        let midY: CGFloat
        let minX: CGFloat
    }

    static func buildLinesWithTwoColumnDetection(_ observations: [VNRecognizedTextObservation]) -> [String] {
        let fragments = observations.compactMap { obs -> OCRLine? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let bbox = obs.boundingBox
            return OCRLine(text: candidate.string, bbox: bbox, midY: bbox.midY, minX: bbox.minX)
        }

        let lines = groupIntoLines(fragments).map { line -> OCRLine in
            let sorted = line.sorted { $0.minX < $1.minX }
            let text = sorted.map(\.text).joined(separator: " ")
            let union = sorted.reduce(CGRect.null) { $0.union($1.bbox) }
            return OCRLine(text: text, bbox: union, midY: union.midY, minX: union.minX)
        }

        let xs = lines.map { $0.minX }.sorted()
        guard xs.count >= 6 else {
            return lines.sorted { $0.midY > $1.midY }.map { $0.text }
        }

        var bestGap: CGFloat = 0
        var splitIndex: Int = 0
        for i in 1..<xs.count {
            let gap = xs[i] - xs[i - 1]
            if gap > bestGap {
                bestGap = gap
                splitIndex = i
            }
        }

        let isTwoColumn = bestGap > 0.15
        if !isTwoColumn {
            return lines.sorted { $0.midY > $1.midY }.map { $0.text }
        }

        let splitX = xs[splitIndex]
        let left = lines.filter { $0.minX < splitX }
            .sorted { $0.midY > $1.midY }
        let right = lines.filter { $0.minX >= splitX }
            .sorted { $0.midY > $1.midY }

        return (left + right).map { $0.text }
    }

    static func groupIntoLines(_ fragments: [OCRLine]) -> [[OCRLine]] {
        let sortedByY = fragments.sorted { $0.midY > $1.midY }

        var lines: [[OCRLine]] = []
        var current: [OCRLine] = []

        var currentMidY: CGFloat = 0
        var currentHeight: CGFloat = 0

        for f in sortedByY {
            if current.isEmpty {
                current = [f]
                currentMidY = f.midY
                currentHeight = f.bbox.height
                continue
            }
            let threshold = max(0.012, currentHeight * 0.6)
            if abs(f.midY - currentMidY) <= threshold {
                current.append(f)
                currentMidY = (currentMidY * CGFloat(current.count - 1) + f.midY) / CGFloat(current.count)
                currentHeight = max(currentHeight, f.bbox.height)
            } else {
                lines.append(current)
                current = [f]
                currentMidY = f.midY
                currentHeight = f.bbox.height
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}
