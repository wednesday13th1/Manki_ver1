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
        let tapEnglish = UITapGestureRecognizer(target: self, action: #selector(handleRevealTap))
        let tapJapanese = UITapGestureRecognizer(target: self, action: #selector(handleRevealTap))
        englishLabel.addGestureRecognizer(tapEnglish)
        japaneseLabel.addGestureRecognizer(tapJapanese)

        englishLabel.translatesAutoresizingMaskIntoConstraints = false
        japaneseLabel.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        importanceButton.translatesAutoresizingMaskIntoConstraints = false

        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        favoriteButton.tintColor = .systemYellow
        favoriteButton.setContentHuggingPriority(.required, for: .horizontal)

        importanceButton.addTarget(self, action: #selector(selectImportance), for: .touchUpInside)
        importanceButton.setTitleColor(.systemBlue, for: .normal)
        importanceButton.layer.cornerRadius = 10
        importanceButton.layer.borderWidth = 1
        importanceButton.layer.borderColor = UIColor.systemBlue.cgColor
        importanceButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        let rowStack = UIStackView(arrangedSubviews: [englishLabel, japaneseLabel, favoriteButton, importanceButton])
        rowStack.axis = .horizontal
        rowStack.spacing = 10
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowStack)

        englishLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        japaneseLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        favoriteButton.setContentHuggingPriority(.required, for: .horizontal)
        importanceButton.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            favoriteButton.widthAnchor.constraint(equalToConstant: 28),
            favoriteButton.heightAnchor.constraint(equalToConstant: 28),
            importanceButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),

            rowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            rowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
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
