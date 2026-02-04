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
    private let searchContainer = UIView()
    private var searchText: String = ""
    private var themeObserver: NSObjectProtocol?
    private let retroShellView = UIView()
    private let retroScreenView = UIView()
    private let retroAntennaView = UIView()
    private let retroAntennaTipView = UIView()
    private let retroSpeakerView = UIView()
    private let retroClickWheelView = UIView()
    private let retroClickWheelCenterView = UIView()
    private let retroClickWheelVerticalDivider = UIView()
    private let retroClickWheelHorizontalDivider = UIView()
    private let retroClickWheelBackButton = UIButton(type: .system)
    private let retroClickWheelAddButton = UIButton(type: .system)
    private let retroClickWheelSortButton = UIButton(type: .system)
    private let retroBadgeLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "戻る"
        configureRetroShell()
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        applyTheme()
        reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAntennaShape()
        updateClickWheelShape()
    }

    private func updateAntennaShape() {
        let bounds = retroAntennaView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let radius = bounds.width / 2
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        retroAntennaView.layer.mask = mask
    }

    private func updateClickWheelShape() {
        let wheelBounds = retroClickWheelView.bounds
        if wheelBounds.width > 0 {
            retroClickWheelView.layer.cornerRadius = wheelBounds.width / 2
        }
        let centerBounds = retroClickWheelCenterView.bounds
        if centerBounds.width > 0 {
            retroClickWheelCenterView.layer.cornerRadius = centerBounds.width / 2
        }
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 6
        }
        retroScreenView.addSubview(searchContainer)
        retroScreenView.addSubview(tableView)

        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchController.searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchController.searchBar)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: retroScreenView.topAnchor, constant: 12),
            searchContainer.leadingAnchor.constraint(equalTo: retroScreenView.leadingAnchor, constant: 12),
            searchContainer.trailingAnchor.constraint(equalTo: retroScreenView.trailingAnchor, constant: -12),

            searchController.searchBar.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: 6),
            searchController.searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 6),
            searchController.searchBar.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -6),
            searchController.searchBar.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: -6),

            tableView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: retroScreenView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: retroScreenView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: retroScreenView.bottomAnchor),
        ])
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "フォルダーがありません。\n下の「追加」で作成できます。"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        retroScreenView.addSubview(emptyLabel)
        retroScreenView.bringSubviewToFront(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: retroScreenView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: retroScreenView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: retroScreenView.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: retroScreenView.trailingAnchor, constant: -20),
        ])
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "フォルダー名で検索"
        searchController.searchBar.sizeToFit()
        definesPresentationContext = true
    }

    private func configureRetroShell() {
        retroShellView.translatesAutoresizingMaskIntoConstraints = false
        retroScreenView.translatesAutoresizingMaskIntoConstraints = false
        retroSpeakerView.translatesAutoresizingMaskIntoConstraints = false
        retroBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        retroAntennaView.translatesAutoresizingMaskIntoConstraints = false
        retroAntennaTipView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelCenterView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelVerticalDivider.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelHorizontalDivider.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelBackButton.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelAddButton.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelSortButton.translatesAutoresizingMaskIntoConstraints = false

        retroBadgeLabel.text = "Y2K"
        retroBadgeLabel.textAlignment = .center

        [retroClickWheelBackButton, retroClickWheelAddButton, retroClickWheelSortButton].forEach { button in
            button.layer.cornerRadius = 10
            button.layer.borderWidth = 1
            button.titleLabel?.font = AppFont.jp(size: 11, weight: .bold)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        }
        retroClickWheelBackButton.setTitle("戻る", for: .normal)
        retroClickWheelAddButton.setTitle("追加", for: .normal)
        retroClickWheelSortButton.setTitle("並替", for: .normal)

        retroShellView.addSubview(retroSpeakerView)
        retroShellView.addSubview(retroAntennaView)
        retroShellView.addSubview(retroAntennaTipView)
        retroShellView.addSubview(retroClickWheelView)
        retroShellView.addSubview(retroBadgeLabel)
        retroShellView.addSubview(retroScreenView)

        retroClickWheelView.addSubview(retroClickWheelVerticalDivider)
        retroClickWheelView.addSubview(retroClickWheelHorizontalDivider)
        retroClickWheelView.addSubview(retroClickWheelCenterView)
        retroClickWheelView.addSubview(retroClickWheelBackButton)
        retroClickWheelView.addSubview(retroClickWheelAddButton)
        retroClickWheelView.addSubview(retroClickWheelSortButton)

        view.addSubview(retroShellView)

        NSLayoutConstraint.activate([
            retroShellView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            retroShellView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            retroShellView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            retroShellView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            retroSpeakerView.topAnchor.constraint(equalTo: retroShellView.topAnchor, constant: 12),
            retroSpeakerView.centerXAnchor.constraint(equalTo: retroShellView.centerXAnchor),
            retroSpeakerView.widthAnchor.constraint(equalToConstant: 72),
            retroSpeakerView.heightAnchor.constraint(equalToConstant: 6),

            retroAntennaView.leadingAnchor.constraint(equalTo: retroShellView.leadingAnchor, constant: 44),
            retroAntennaView.topAnchor.constraint(equalTo: retroShellView.topAnchor, constant: -60),
            retroAntennaView.widthAnchor.constraint(equalToConstant: 20),
            retroAntennaView.heightAnchor.constraint(equalToConstant: 85),

            retroAntennaTipView.centerXAnchor.constraint(equalTo: retroAntennaView.centerXAnchor),
            retroAntennaTipView.bottomAnchor.constraint(equalTo: retroAntennaView.topAnchor, constant: 4),
            retroAntennaTipView.widthAnchor.constraint(equalToConstant: 24),
            retroAntennaTipView.heightAnchor.constraint(equalToConstant: 24),

            retroBadgeLabel.centerYAnchor.constraint(equalTo: retroSpeakerView.centerYAnchor),
            retroBadgeLabel.trailingAnchor.constraint(equalTo: retroShellView.trailingAnchor, constant: -16),
            retroBadgeLabel.widthAnchor.constraint(equalToConstant: 44),
            retroBadgeLabel.heightAnchor.constraint(equalToConstant: 20),

            retroScreenView.topAnchor.constraint(equalTo: retroSpeakerView.bottomAnchor, constant: 4),
            retroScreenView.leadingAnchor.constraint(equalTo: retroShellView.leadingAnchor, constant: 12),
            retroScreenView.trailingAnchor.constraint(equalTo: retroShellView.trailingAnchor, constant: -12),

            retroClickWheelView.topAnchor.constraint(equalTo: retroScreenView.bottomAnchor, constant: 16),
            retroClickWheelView.centerXAnchor.constraint(equalTo: retroShellView.centerXAnchor),
            retroClickWheelView.bottomAnchor.constraint(equalTo: retroShellView.bottomAnchor, constant: -16),

            retroClickWheelCenterView.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            retroClickWheelCenterView.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelCenterView.widthAnchor.constraint(equalToConstant: 48),
            retroClickWheelCenterView.heightAnchor.constraint(equalToConstant: 48),

            retroClickWheelVerticalDivider.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            retroClickWheelVerticalDivider.topAnchor.constraint(equalTo: retroClickWheelView.topAnchor, constant: 18),
            retroClickWheelVerticalDivider.bottomAnchor.constraint(equalTo: retroClickWheelView.bottomAnchor, constant: -18),
            retroClickWheelVerticalDivider.widthAnchor.constraint(equalToConstant: 2),

            retroClickWheelHorizontalDivider.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelHorizontalDivider.leadingAnchor.constraint(equalTo: retroClickWheelView.leadingAnchor, constant: 18),
            retroClickWheelHorizontalDivider.trailingAnchor.constraint(equalTo: retroClickWheelView.trailingAnchor, constant: -18),
            retroClickWheelHorizontalDivider.heightAnchor.constraint(equalToConstant: 2),

            retroClickWheelBackButton.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelBackButton.centerXAnchor.constraint(equalTo: retroClickWheelView.leadingAnchor, constant: 35),
            retroClickWheelBackButton.widthAnchor.constraint(equalToConstant: 50),
            retroClickWheelBackButton.heightAnchor.constraint(equalToConstant: 32),

            retroClickWheelAddButton.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelAddButton.centerXAnchor.constraint(equalTo: retroClickWheelView.trailingAnchor, constant: -35),
            retroClickWheelAddButton.widthAnchor.constraint(equalToConstant: 50),
            retroClickWheelAddButton.heightAnchor.constraint(equalToConstant: 32),

            retroClickWheelSortButton.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            retroClickWheelSortButton.centerYAnchor.constraint(equalTo: retroClickWheelView.topAnchor, constant: 30),
            retroClickWheelSortButton.widthAnchor.constraint(equalToConstant: 50),
            retroClickWheelSortButton.heightAnchor.constraint(equalToConstant: 32),

        ])

        let screenMinHeight = retroScreenView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        screenMinHeight.priority = .defaultLow
        screenMinHeight.isActive = true

        let wheelPreferredSize = retroClickWheelView.heightAnchor.constraint(equalToConstant: 130)
        wheelPreferredSize.priority = .defaultHigh
        wheelPreferredSize.isActive = true
        let wheelMaxHeight = retroClickWheelView.heightAnchor.constraint(lessThanOrEqualToConstant: 140)
        wheelMaxHeight.priority = .required
        wheelMaxHeight.isActive = true
        let wheelMinHeight = retroClickWheelView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
        wheelMinHeight.priority = .defaultLow
        wheelMinHeight.isActive = true
        retroClickWheelView.widthAnchor.constraint(equalTo: retroClickWheelView.heightAnchor).isActive = true
        retroClickWheelBackButton.addTarget(self, action: #selector(closeSelf), for: .touchUpInside)
        retroClickWheelAddButton.addTarget(self, action: #selector(addFolder), for: .touchUpInside)
        retroClickWheelSortButton.addTarget(self, action: #selector(openSortMenu), for: .touchUpInside)
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
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 6
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView(frame: .zero)
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 6
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView(frame: .zero)
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
        if let navigationController, navigationController.viewControllers.first != self {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        ThemeManager.applySearchBar(searchController.searchBar)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.separatorColor = palette.border
        tableView.showsVerticalScrollIndicator = false
        emptyLabel.font = AppFont.jp(size: 16)
        emptyLabel.textColor = palette.mutedText

        searchContainer.backgroundColor = palette.surface
        searchContainer.layer.cornerRadius = 12
        searchContainer.layer.borderWidth = 1.5
        searchContainer.layer.borderColor = palette.border.cgColor

        retroShellView.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        retroShellView.layer.cornerRadius = 36
        retroShellView.layer.borderWidth = 0.5
        retroShellView.layer.borderColor = UIColor(white: 0.2, alpha: 1.0).cgColor
        retroShellView.layer.shadowColor = palette.border.cgColor
        retroShellView.layer.shadowOpacity = 0.18
        retroShellView.layer.shadowOffset = CGSize(width: 0, height: 6)
        retroShellView.layer.shadowRadius = 12

        retroScreenView.backgroundColor = palette.accentStrong
        retroScreenView.layer.cornerRadius = 0
        retroScreenView.layer.borderWidth = 8
        retroScreenView.layer.borderColor = UIColor.darkGray.cgColor
        retroScreenView.clipsToBounds = true

        retroSpeakerView.backgroundColor = palette.border.withAlphaComponent(0.7)
        retroSpeakerView.layer.cornerRadius = 3

        retroAntennaView.backgroundColor = UIColor.black
        retroAntennaView.layer.cornerRadius = 0
        retroAntennaView.layer.borderWidth = 0
        retroAntennaTipView.backgroundColor = UIColor.systemGray
        retroAntennaTipView.layer.cornerRadius = 12

        retroClickWheelView.backgroundColor = UIColor.systemGray5
        retroClickWheelView.layer.borderWidth = 2
        retroClickWheelView.layer.borderColor = UIColor.systemGray3.cgColor
        retroClickWheelCenterView.backgroundColor = UIColor.systemGray4
        retroClickWheelVerticalDivider.backgroundColor = UIColor.systemGray2
        retroClickWheelHorizontalDivider.backgroundColor = UIColor.systemGray2

        [retroClickWheelBackButton, retroClickWheelAddButton, retroClickWheelSortButton].forEach { button in
            button.backgroundColor = UIColor.systemGray6
            button.layer.borderColor = UIColor.systemGray3.cgColor
            button.setTitleColor(palette.text, for: .normal)
        }

        retroBadgeLabel.font = AppFont.jp(size: 10, weight: .bold)
        retroBadgeLabel.textColor = palette.text
        retroBadgeLabel.backgroundColor = palette.surface
        retroBadgeLabel.layer.cornerRadius = 6
        retroBadgeLabel.layer.masksToBounds = true

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
        alert.popoverPresentationController?.sourceView = retroClickWheelView
        alert.popoverPresentationController?.sourceRect = retroClickWheelView.bounds
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
        let unclassifiedCount = sets.filter { $0.folderID == nil }.count
        emptyLabel.isHidden = !(folders.isEmpty && unclassifiedCount == 0)
        tableView.reloadData()
    }
}

extension FolderViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyFilterAndReload()
    }
}
