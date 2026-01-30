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
    private let notebookBackgroundView = NotebookBackgroundView()
    private let favoriteButton = UIButton(type: .system)
    private let importanceButton = UIButton(type: .system)
    private var isFavorite = false
    private var currentLevel = 1

    var onFavoriteChanged: ((Bool) -> Void)?
    var onImportanceChanged: ((Int) -> Void)?
    var onSelectImportanceTapped: (() -> Void)?
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
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        importanceButton.translatesAutoresizingMaskIntoConstraints = false
        notebookBackgroundView.translatesAutoresizingMaskIntoConstraints = false

        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        favoriteButton.tintColor = .systemYellow
        favoriteButton.setContentHuggingPriority(.required, for: .horizontal)

        importanceButton.addTarget(self, action: #selector(selectImportance), for: .touchUpInside)
        importanceButton.setTitleColor(.systemBlue, for: .normal)
        importanceButton.layer.cornerRadius = 10
        importanceButton.layer.borderWidth = 1
        importanceButton.layer.borderColor = UIColor.systemBlue.cgColor
        importanceButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        if let currentSize = importanceButton.titleLabel?.font.pointSize {
            importanceButton.titleLabel?.font = AppFont.en(size: currentSize)
        }

        let rowStack = UIStackView(arrangedSubviews: [englishLabel, japaneseLabel, favoriteButton, importanceButton])
        rowStack.axis = .horizontal
        rowStack.spacing = 10
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(notebookBackgroundView)
        notebookBackgroundView.addSubview(rowStack)

        englishLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        japaneseLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        favoriteButton.setContentHuggingPriority(.required, for: .horizontal)
        importanceButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            favoriteButton.widthAnchor.constraint(equalToConstant: 28),
            favoriteButton.heightAnchor.constraint(equalToConstant: 28),
            importanceButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),

            notebookBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            notebookBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            notebookBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            notebookBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            rowStack.leadingAnchor.constraint(equalTo: notebookBackgroundView.leadingAnchor, constant: 36),
            rowStack.trailingAnchor.constraint(equalTo: notebookBackgroundView.trailingAnchor, constant: -12),
            rowStack.topAnchor.constraint(equalTo: notebookBackgroundView.topAnchor, constant: 10),
            rowStack.bottomAnchor.constraint(equalTo: notebookBackgroundView.bottomAnchor, constant: -10),
        ])
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFavoriteChanged = nil
        onImportanceChanged = nil
        onSelectImportanceTapped = nil
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
        applyHiddenMode(hiddenMode, isRevealed: isRevealed)
        isFavorite = word.isFavorite
        currentLevel = max(1, min(5, word.importanceLevel))
        updateFavoriteAppearance()
        updateImportanceButton()
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

    @objc private func selectImportance() {
        onSelectImportanceTapped?()
    }

    @objc private func handleRevealTap() {
        onToggleReveal?()
    }

    func updateImportance(level: Int) {
        currentLevel = max(1, min(5, level))
        updateImportanceButton()
    }

    private func updateImportanceButton() {
        importanceButton.setTitle("Lv\(currentLevel)", for: .normal)
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
        let holeX = leftMargin - 16
        var holeY: CGFloat = 20

        context.setStrokeColor(holeStrokeColor.cgColor)
        context.setLineWidth(1)
        while holeY < rect.height - 12 {
            let holeRect = CGRect(x: holeX - holeRadius,
                                  y: holeY - holeRadius,
                                  width: holeRadius * 2,
                                  height: holeRadius * 2)
            context.strokeEllipse(in: holeRect)
            holeY += holeSpacing
        }
    }
}
