//
//  FolderViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class FolderViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var folders: [SavedFolder] = []
    private var filteredFolders: [SavedFolder] = []
    private var sets: [SavedSet] = []
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText: String = ""
    private var themeObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "フォルダー"
        configureTableView()
        configureEmptyLabel()
        configureSearch()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "追加",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(addFolder))
        let closeButton = UIBarButtonItem(title: "戻る",
                                          style: .plain,
                                          target: self,
                                          action: #selector(closeSelf))
        let wordButton = UIBarButtonItem(title: "単語",
                                         style: .plain,
                                         target: self,
                                         action: #selector(openWordList))
        navigationItem.leftBarButtonItems = [closeButton, wordButton]
        let sortButton = UIBarButtonItem(title: "並び替え",
                                         style: .plain,
                                         target: self,
                                         action: #selector(openSortMenu))
        navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItem, sortButton].compactMap { $0 }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
        reloadData()
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "フォルダーがありません。\n右上の「追加」で作成できます。"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "フォルダー名で検索"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
    }

    private func reloadData() {
        folders = FolderStore.loadFolders()
        sets = SetStore.loadSets()
        applyFilterAndReload()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return displayedFolders().count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? nil : "フォルダー"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "folderCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        if indexPath.section == 0 {
            let count = sets.filter { $0.folderID == nil }.count
            cell.textLabel?.text = "未分類"
            cell.detailTextLabel?.text = "セット \(count) 個"
        } else {
            let folder = displayedFolders()[indexPath.row]
            let count = sets.filter { $0.folderID == folder.id }.count
            cell.textLabel?.text = folder.name
            cell.detailTextLabel?.text = "セット \(count) 個"
        }
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.font = AppFont.jp(size: 18, weight: .bold)
        cell.detailTextLabel?.font = AppFont.jp(size: 14)
        let palette = ThemeManager.palette()
        cell.backgroundColor = palette.surface
        cell.textLabel?.textColor = palette.text
        cell.detailTextLabel?.textColor = palette.mutedText
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let controller = SetViewController(folderID: nil)
            navigationController?.pushViewController(controller, animated: true)
            return
        }
        let folder = displayedFolders()[indexPath.row]
        let controller = SetViewController(folderID: folder.id)
        controller.title = folder.name
        navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else { return nil }
        let rename = UIContextualAction(style: .normal, title: "名前変更") { [weak self] _, _, completion in
            self?.renameFolder(at: indexPath)
            completion(true)
        }
        rename.backgroundColor = .systemBlue
        let delete = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
            self?.deleteFolder(at: indexPath)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, rename])
    }

    @objc private func addFolder() {
        let alert = UIAlertController(title: "フォルダー追加", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "フォルダー名"
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            var folders = FolderStore.loadFolders()
            folders.append(SavedFolder(name: name))
            FolderStore.saveFolders(folders)
            self.reloadData()
        })
        present(alert, animated: true)
    }

    @objc private func openWordList() {
        guard let listVC = storyboard?.instantiateViewController(withIdentifier: "ListTableViewController") else {
            return
        }
        navigationController?.pushViewController(listVC, animated: true)
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        ThemeManager.applySearchBar(searchController.searchBar)
        let barAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 14, weight: .bold),
            .foregroundColor: palette.text
        ]
        (navigationItem.leftBarButtonItems ?? []).forEach { item in
            item.setTitleTextAttributes(barAttributes, for: .normal)
            item.setTitleTextAttributes(barAttributes, for: .highlighted)
        }
        (navigationItem.rightBarButtonItems ?? []).forEach { item in
            item.setTitleTextAttributes(barAttributes, for: .normal)
            item.setTitleTextAttributes(barAttributes, for: .highlighted)
        }
        tableView.backgroundColor = .clear
        tableView.separatorColor = palette.border
        emptyLabel.font = AppFont.jp(size: 16)
        emptyLabel.textColor = palette.mutedText
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func renameFolder(at indexPath: IndexPath) {
        let folder = displayedFolders()[indexPath.row]
        let alert = UIAlertController(title: "名前変更", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = folder.name
            field.placeholder = "フォルダー名"
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            var folders = FolderStore.loadFolders()
            if let index = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[index].name = name
                FolderStore.saveFolders(folders)
                self.reloadData()
            }
        })
        present(alert, animated: true)
    }

    private func deleteFolder(at indexPath: IndexPath) {
        let folder = displayedFolders()[indexPath.row]
        var folders = FolderStore.loadFolders()
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders.remove(at: index)
            FolderStore.saveFolders(folders)
        }
        var sets = SetStore.loadSets()
        for idx in sets.indices {
            if sets[idx].folderID == folder.id {
                sets[idx].folderID = nil
            }
        }
        SetStore.saveSets(sets)
        reloadData()
    }

    @objc private func openSortMenu() {
        let alert = UIAlertController(title: "並び替え", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "作成順", style: .default) { [weak self] _ in
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "名前 A→Z", style: .default) { [weak self] _ in
            self?.applyFilterAndReload(sortByNameAsc: true)
        })
        alert.addAction(UIAlertAction(title: "名前 Z→A", style: .default) { [weak self] _ in
            self?.applyFilterAndReload(sortByNameAsc: false)
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(alert, animated: true)
    }

    private func displayedFolders() -> [SavedFolder] {
        if searchText.isEmpty {
            return filteredFolders.isEmpty ? folders : filteredFolders
        }
        return filteredFolders
    }

    private func applyFilterAndReload(sortByNameAsc: Bool? = nil) {
        if searchText.isEmpty {
            filteredFolders = []
        } else {
            filteredFolders = folders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if let sortAsc = sortByNameAsc {
            let target = searchText.isEmpty ? folders : filteredFolders
            let sorted = target.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == (sortAsc ? .orderedAscending : .orderedDescending)
            }
            if searchText.isEmpty {
                folders = sorted
            } else {
                filteredFolders = sorted
            }
        }
        emptyLabel.isHidden = !folders.isEmpty
        tableView.reloadData()
    }
}

extension FolderViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyFilterAndReload()
    }
}
