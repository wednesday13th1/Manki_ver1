//
//  LuckyCollectionViewController.swift
//  manki
//
//  Created by Codex.
//

import UIKit

final class LuckyCollectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private var entries: [LuckyStore.LuckyEntry] = []
    private var themeObserver: NSObjectProtocol?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "おみくじコレクション"
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    private func configureUI() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "まだ引いていません"
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        emptyLabel.font = AppFont.jp(size: 16, weight: .bold)
        emptyLabel.textColor = palette.mutedText
        tableView.backgroundColor = .clear
        tableView.separatorColor = palette.border
        tableView.reloadData()
    }

    private func reloadData() {
        entries = LuckyStore.loadHistory()
        emptyLabel.isHidden = !entries.isEmpty
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "luckyCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        let entry = entries[indexPath.row]
        cell.textLabel?.text = entry.message
        cell.detailTextLabel?.text = dateFormatter.string(from: entry.date)
        cell.textLabel?.numberOfLines = 0
        applyCellTheme(cell)
        return cell
    }

    private func applyCellTheme(_ cell: UITableViewCell) {
        let palette = ThemeManager.palette()
        cell.backgroundColor = palette.surface
        cell.textLabel?.font = AppFont.jp(size: 16, weight: .bold)
        cell.textLabel?.textColor = palette.text
        cell.detailTextLabel?.font = AppFont.jp(size: 12, weight: .bold)
        cell.detailTextLabel?.textColor = palette.mutedText
        cell.layer.borderWidth = 1
        cell.layer.borderColor = palette.border.cgColor
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
