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

        englishLabel.translatesAutoresizingMaskIntoConstraints = false
        japaneseLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            englishLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            englishLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            englishLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            japaneseLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            japaneseLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            japaneseLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            englishLabel.trailingAnchor.constraint(equalTo: japaneseLabel.leadingAnchor, constant: -10),
            englishLabel.widthAnchor.constraint(equalTo: japaneseLabel.widthAnchor)
        ])
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func applyHiddenMode(_ mode: WordHiddenMode) {
        switch mode {
        case .none:
            englishLabel.textColor = .label
            englishLabel.backgroundColor = .clear
            japaneseLabel.textColor = .label
            japaneseLabel.backgroundColor = .clear
        case .english:
            englishLabel.textColor = .clear
            englishLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.6)
            japaneseLabel.textColor = .label
            japaneseLabel.backgroundColor = .clear
        case .japanese:
            englishLabel.textColor = .label
            englishLabel.backgroundColor = .clear
            japaneseLabel.textColor = .clear
            japaneseLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.6)
        }
    }
    
}
