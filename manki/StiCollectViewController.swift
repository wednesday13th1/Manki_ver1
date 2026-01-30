//
//  StiCollectViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/29.
//

import UIKit

final class StiCollectViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private var stickers: [SavedSticker] = []
    private var stickerWordMap: [String: [SavedWord]] = [:]
    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()
    var selectionHandler: ((SavedSticker) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = selectionHandler == nil ? "ステッカーコレクション" : "ステッカーを選ぶ"
        view.backgroundColor = .systemBackground
        configureCollectionView()
        configureEmptyLabel()
        configureSelectionBarItem()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadStickers()
    }

    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(StickerCell.self, forCellWithReuseIdentifier: StickerCell.reuseID)

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "まだステッカーがありません"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true

        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func reloadStickers() {
        stickers = StickerStore.loadStickers()
        let words = loadSavedWords()
        stickerWordMap = Dictionary(grouping: words.compactMap { word in
            guard word.illustrationImageFileName != nil else { return nil }
            return word
        }, by: { $0.illustrationImageFileName ?? "" })
        collectionView.reloadData()
        emptyLabel.isHidden = !stickers.isEmpty
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        stickers.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StickerCell.reuseID,
                                                            for: indexPath) as? StickerCell else {
            return UICollectionViewCell()
        }
        let sticker = stickers[indexPath.item]
        let wordText = wordLabelText(for: sticker.imageFileName)
        cell.configure(with: StickerStore.loadStickerImage(fileName: sticker.imageFileName),
                       wordText: wordText)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let sticker = stickers[indexPath.item]
        if let selectionHandler {
            selectionHandler(sticker)
            if let nav = navigationController, nav.viewControllers.first != self {
                nav.popViewController(animated: true)
            } else {
                dismiss(animated: true)
            }
            return
        }

        let alert = UIAlertController(title: "ステッカー",
                                      message: "このステッカーを削除しますか？",
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "削除", style: .destructive) { [weak self] _ in
            self?.deleteSticker(at: indexPath)
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = collectionView
            popover.sourceRect = collectionView.layoutAttributesForItem(at: indexPath)?.frame ?? collectionView.bounds
        }
        present(alert, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = collectionView.bounds.width < 360 ? 2 : 3
        let totalSpacing: CGFloat = (columns - 1) * 12
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width + 38)
    }

    private func configureSelectionBarItem() {
        guard selectionHandler != nil else { return }
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "閉じる",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(closeTapped))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func deleteSticker(at indexPath: IndexPath) {
        guard indexPath.item < stickers.count else { return }
        let sticker = stickers[indexPath.item]
        StickerStore.deleteStickerImage(fileName: sticker.imageFileName)
        stickers.remove(at: indexPath.item)
        StickerStore.saveStickers(stickers)
        collectionView.deleteItems(at: [indexPath])
        emptyLabel.isHidden = !stickers.isEmpty
    }

    private func wordLabelText(for fileName: String) -> NSAttributedString? {
        guard let words = stickerWordMap[fileName], let first = words.first else { return nil }
        let englishAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.en(size: 14, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let japaneseAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 12, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let result = NSMutableAttributedString(string: first.english, attributes: englishAttributes)
        var japaneseLine = first.japanese
        if words.count > 1 {
            japaneseLine += " ほか\(words.count - 1)"
        }
        result.append(NSAttributedString(string: "\n", attributes: japaneseAttributes))
        result.append(NSAttributedString(string: japaneseLine, attributes: japaneseAttributes))
        return result
    }

    private func loadSavedWords() -> [SavedWord] {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let fileURL = documents.appendingPathComponent("saved_words.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            return decoded
        }
        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        return legacy.map {
            SavedWord(english: $0["english"] ?? "",
                      japanese: $0["japanese"] ?? "",
                      illustrationScenario: nil,
                      illustrationImageFileName: nil)
        }
    }
}

private final class StickerCell: UICollectionViewCell {
    static let reuseID = "StickerCell"

    private let imageView = UIImageView()
    private let wordLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        contentView.backgroundColor = UIColor.systemGray6
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        wordLabel.translatesAutoresizingMaskIntoConstraints = false
        wordLabel.numberOfLines = 2
        wordLabel.textAlignment = .center
        contentView.addSubview(wordLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),

            wordLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            wordLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            wordLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            wordLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    func configure(with image: UIImage?, wordText: NSAttributedString?) {
        imageView.image = image
        wordLabel.attributedText = wordText
        wordLabel.isHidden = (wordText == nil)
    }
}
