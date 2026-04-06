//
//  ListTableViewCell.swift
//  manki
//
//  Created by 井上　希稟 on 2025/12/29.
//

import UIKit

enum WordHiddenMode {
    case none
    case english
    case japanese
}

class ListTableViewCell: UITableViewCell {

    @IBOutlet var englishLabel: UILabel!
    @IBOutlet var japaneseLabel: UILabel!
    private let exampleLabel = UILabel()
    private let notebookBackgroundView = NotebookBackgroundView()
    private let favoriteButton = UIButton(type: .system)
    private var isFavorite = false

    var onFavoriteChanged: ((Bool) -> Void)?
    var onToggleReveal: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        englishLabel.layer.cornerRadius = 4
        englishLabel.layer.masksToBounds = true
        japaneseLabel.layer.cornerRadius = 4
        japaneseLabel.layer.masksToBounds = true
        englishLabel.numberOfLines = 0
        englishLabel.lineBreakMode = .byWordWrapping
        japaneseLabel.numberOfLines = 0
        japaneseLabel.lineBreakMode = .byWordWrapping
        exampleLabel.numberOfLines = 0
        exampleLabel.lineBreakMode = .byWordWrapping
        exampleLabel.textColor = .secondaryLabel
        englishLabel.isUserInteractionEnabled = true
        japaneseLabel.isUserInteractionEnabled = true
        let labelConstraints = contentView.constraints.filter { constraint in
            guard let first = constraint.firstItem as? UIView,
                  let second = constraint.secondItem as? UIView else {
                return (constraint.firstItem as? UIView) == englishLabel
                    || (constraint.firstItem as? UIView) == japaneseLabel
            }
            return first == englishLabel || first == japaneseLabel
                || second == englishLabel || second == japaneseLabel
        }
        NSLayoutConstraint.deactivate(labelConstraints)
        let tapEnglish = UITapGestureRecognizer(target: self, action: #selector(handleRevealTap))
        let tapJapanese = UITapGestureRecognizer(target: self, action: #selector(handleRevealTap))
        englishLabel.addGestureRecognizer(tapEnglish)
        japaneseLabel.addGestureRecognizer(tapJapanese)

        englishLabel.translatesAutoresizingMaskIntoConstraints = false
        japaneseLabel.translatesAutoresizingMaskIntoConstraints = false
        exampleLabel.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        notebookBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        favoriteButton.tintColor = .systemYellow
        favoriteButton.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [englishLabel, japaneseLabel, exampleLabel])
        textStack.axis = .vertical
        textStack.spacing = AppSpacing.s(4)
        textStack.alignment = .fill
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = UIStackView(arrangedSubviews: [textStack, favoriteButton])
        rowStack.axis = .horizontal
        rowStack.spacing = AppSpacing.s(10)
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(notebookBackgroundView)
        notebookBackgroundView.addSubview(rowStack)

        englishLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        japaneseLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        exampleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        favoriteButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            favoriteButton.widthAnchor.constraint(equalToConstant: 28),
            favoriteButton.heightAnchor.constraint(equalToConstant: 28),

            notebookBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(8)),
            notebookBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(8)),
            notebookBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(6)),
            notebookBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(6)),

            rowStack.leadingAnchor.constraint(equalTo: notebookBackgroundView.leadingAnchor, constant: AppSpacing.s(36)),
            rowStack.trailingAnchor.constraint(equalTo: notebookBackgroundView.trailingAnchor, constant: -AppSpacing.s(12)),
            rowStack.topAnchor.constraint(equalTo: notebookBackgroundView.topAnchor, constant: AppSpacing.s(10)),
            rowStack.bottomAnchor.constraint(equalTo: notebookBackgroundView.bottomAnchor, constant: -AppSpacing.s(10)),
        ])
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFavoriteChanged = nil
        onToggleReveal = nil
    }

    func applyHiddenMode(_ mode: WordHiddenMode, isRevealed: Bool) {
        switch mode {
        case .none:
            englishLabel.textColor = .label
            englishLabel.backgroundColor = .clear
            japaneseLabel.textColor = .label
            japaneseLabel.backgroundColor = .clear
        case .english:
            englishLabel.textColor = isRevealed ? .label : .clear
            englishLabel.backgroundColor = isRevealed ? .clear : UIColor.systemRed.withAlphaComponent(0.6)
            japaneseLabel.textColor = .label
            japaneseLabel.backgroundColor = .clear
        case .japanese:
            englishLabel.textColor = .label
            englishLabel.backgroundColor = .clear
            japaneseLabel.textColor = isRevealed ? .label : .clear
            japaneseLabel.backgroundColor = isRevealed ? .clear : UIColor.systemRed.withAlphaComponent(0.6)
        }
    }

    func configure(word: SavedWord, hiddenMode: WordHiddenMode, isRevealed: Bool) {
        selectionStyle = .none
        englishLabel.text = word.english
        japaneseLabel.text = word.japanese
        englishLabel.font = AppFont.en(size: englishLabel.font.pointSize)
        japaneseLabel.font = AppFont.jp(size: japaneseLabel.font.pointSize)
        exampleLabel.font = AppFont.jp(size: 12)
        let example = word.exampleSentence?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        exampleLabel.text = example.isEmpty ? "" : "例文: \(example)"
        exampleLabel.isHidden = example.isEmpty
        applyHiddenMode(hiddenMode, isRevealed: isRevealed)
        isFavorite = word.isFavorite
        updateFavoriteAppearance()
    }

    private func updateFavoriteAppearance() {
        let imageName = isFavorite ? "star.fill" : "star"
        favoriteButton.setImage(UIImage(systemName: imageName), for: .normal)
    }

    @objc private func toggleFavorite() {
        isFavorite.toggle()
        updateFavoriteAppearance()
        onFavoriteChanged?(isFavorite)
    }

    @objc private func handleRevealTap() {
        onToggleReveal?()
    }

    func updateImportance(level: Int) {
        _ = level
    }
}

final class NotebookBackgroundView: UIView {
    private let lineColor = UIColor(red: 0.84, green: 0.87, blue: 0.92, alpha: 1.0)
    private let marginLineColor = UIColor(red: 0.92, green: 0.40, blue: 0.40, alpha: 1.0)
    private let holeStrokeColor = UIColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1.0)
        layer.cornerRadius = 12
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        contentMode = .redraw
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let lineSpacing: CGFloat = 16
        let topInset: CGFloat = 12
        let leftMargin: CGFloat = 26
        let rightInset: CGFloat = 12

        context.setLineWidth(1)
        context.setStrokeColor(lineColor.cgColor)

        var y = topInset
        while y < rect.height - 8 {
            context.move(to: CGPoint(x: leftMargin, y: y))
            context.addLine(to: CGPoint(x: rect.width - rightInset, y: y))
            y += lineSpacing
        }
        context.strokePath()

        context.setStrokeColor(marginLineColor.cgColor)
        context.setLineWidth(1.2)
        context.move(to: CGPoint(x: leftMargin - 8, y: 8))
        context.addLine(to: CGPoint(x: leftMargin - 8, y: rect.height - 8))
        context.strokePath()

        let holeRadius: CGFloat = 5.5
        let holeSpacing: CGFloat = 28
        let holeStartY: CGFloat = 18
        let holeX: CGFloat = 10

        context.setStrokeColor(holeStrokeColor.cgColor)
        context.setLineWidth(1)

        var holeY = holeStartY
        while holeY < rect.height - 10 {
            let holeRect = CGRect(x: holeX - holeRadius,
                                  y: holeY - holeRadius,
                                  width: holeRadius * 2,
                                  height: holeRadius * 2)
            context.strokeEllipse(in: holeRect)
            holeY += holeSpacing
        }
    }
}
