//
//  SetViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/23.
//

import UIKit

private func needsWordIDMigration(from data: Data) -> Bool {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        return false
    }
    return json.contains { $0["id"] == nil }
}

final class SetViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {

    private let savedWordsFileName = "saved_words.json"
    private enum SetSortOption {
        case created
        case nameAsc
        case nameDesc
        case countAsc
        case countDesc
    }
    private let folderID: String?
    private let showsAll: Bool
    private var sets: [SavedSet] = []
    private var wordsByID: [String: SavedWord] = [:]
    private var filteredSets: [SavedSet] = []
    private var displayedSetCache: [SavedSet] = []
    private var sortOption: SetSortOption = .created
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText: String = ""
    private let themeHeader = UIView()
    private let themeTitleLabel = UILabel()
    private let themeStack = UIStackView()
    private var themeButtons: [UIButton] = []
    private var themeObserver: NSObjectProtocol?
    private let themeHeaderHeight: CGFloat = 120
    private let headerContainer = UIView()
    private let hideToggleButton = UIButton(type: .system)
    private var renameGesture: UILongPressGestureRecognizer?

    init(folderID: String?, showsAll: Bool = false) {
        self.folderID = folderID
        self.showsAll = showsAll
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        folderID = nil
        showsAll = true
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = showsAll ? "セット" : (folderID == nil ? "未分類" : "セット")
        view.backgroundColor = .systemBackground
        configureTableView()
        configureEmptyLabel()
        configureSearch()
        configureThemeHeader()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }

        let addButton = UIBarButtonItem(title: "追加",
                                        style: .plain,
                                        target: self,
                                        action: #selector(openAddSet))
        let sortButton = UIBarButtonItem(title: "並び替え",
                                         style: .plain,
                                         target: self,
                                         action: #selector(openSortMenu))
        navigationItem.rightBarButtonItems = [addButton, sortButton]
        let wordsButton = UIBarButtonItem(title: "単語",
                                          style: .plain,
                                          target: self,
                                          action: #selector(openWordList))
        let foldersButton = UIBarButtonItem(title: "フォルダー",
                                            style: .plain,
                                            target: self,
                                            action: #selector(backToFolders))
        navigationItem.leftBarButtonItems = [foldersButton, wordsButton]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
        reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = true
        tableView.allowsSelectionDuringEditing = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let header = tableView.tableHeaderView {
            let targetHeight = themeHeaderHeight
            let targetWidth = tableView.bounds.width
            if header.frame.height != targetHeight || header.frame.width != targetWidth {
                header.frame.size.width = targetWidth
                header.frame.size.height = targetHeight
                tableView.tableHeaderView = header
            }
        }
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        tableView.delaysContentTouches = false
        view.addSubview(tableView)
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleSetRenameLongPress(_:)))
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesBegan = false
        gesture.delegate = self
        tableView.addGestureRecognizer(gesture)
        renameGesture = gesture

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "セットがありません。\n右上の「追加」で作成できます。"
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
        searchController.searchBar.placeholder = "セット名で検索"
        navigationItem.searchController = searchController // 検索
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
    }

    private func configureThemeHeader() {
        themeHeader.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: themeHeaderHeight)
        themeHeader.translatesAutoresizingMaskIntoConstraints = false

        themeTitleLabel.text = "テーマ"
        themeTitleLabel.textAlignment = .left

        themeStack.axis = .horizontal
        themeStack.spacing = 12
        themeStack.alignment = .center
        themeStack.distribution = .fillEqually
        themeStack.translatesAutoresizingMaskIntoConstraints = false

        themeButtons = AppTheme.allCases.enumerated().map { index, theme in
            let button = UIButton(type: .system)
            button.tag = index
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 2
            button.addTarget(self, action: #selector(selectTheme(_:)), for: .touchUpInside)
            return button
        }
        themeButtons.forEach { themeStack.addArrangedSubview($0) }

        themeHeader.addSubview(themeTitleLabel)
        themeHeader.addSubview(themeStack)
        themeTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            themeTitleLabel.topAnchor.constraint(equalTo: themeHeader.topAnchor, constant: 12),
            themeTitleLabel.leadingAnchor.constraint(equalTo: themeHeader.leadingAnchor, constant: 20),
            themeTitleLabel.trailingAnchor.constraint(equalTo: themeHeader.trailingAnchor, constant: -20),

            themeStack.topAnchor.constraint(equalTo: themeTitleLabel.bottomAnchor, constant: 12),
            themeStack.leadingAnchor.constraint(equalTo: themeHeader.leadingAnchor, constant: 20),
            themeStack.trailingAnchor.constraint(equalTo: themeHeader.trailingAnchor, constant: -20),
            themeStack.heightAnchor.constraint(equalToConstant: 36),
        ])

        tableView.tableHeaderView = themeHeader
    }

    private func reloadData() {
        let allSets = SetStore.loadSets()
        if showsAll {
            sets = allSets
        } else {
            sets = allSets.filter { $0.folderID == folderID }
        }
        let words = loadSavedWords()
        wordsByID = Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
        applyFilterAndReload()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedSets().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "setCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        let set = displayedSets()[indexPath.row]
        let count = wordCount(for: set)
        cell.textLabel?.text = set.name
        cell.detailTextLabel?.text = "単語 \(count) 個"
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
        let set = displayedSets()[indexPath.row]
        let controller = SetDetailViewController(setID: set.id)
        if let nav = navigationController {
            nav.pushViewController(controller, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let move = UIContextualAction(style: .normal, title: "フォルダー") { [weak self] _, _, completion in
            self?.showMoveSetSheet(for: indexPath)
            completion(true)
        }
        move.backgroundColor = .systemBlue
        let delete = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
            self?.deleteSet(at: indexPath)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, move])
    }

    @objc private func openAddSet() {
        let controller = SetCreateViewController(folderID: folderID)
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openWordList() {
        guard let listVC = storyboard?.instantiateViewController(withIdentifier: "ListTableViewController") else {
            return
        }
        navigationController?.pushViewController(listVC, animated: true)
    }

    @objc private func backToFolders() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func selectTheme(_ sender: UIButton) {
        let themes = AppTheme.allCases
        guard sender.tag >= 0, sender.tag < themes.count else { return }
        ThemeManager.setTheme(themes[sender.tag])
        updateThemeSelection()
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        ThemeManager.applySearchBar(searchController.searchBar)

        tableView.backgroundColor = .clear
        tableView.separatorColor = palette.border
        emptyLabel.font = AppFont.jp(size: 16)
        emptyLabel.textColor = palette.mutedText

        themeHeader.backgroundColor = palette.surface
        themeHeader.layer.cornerRadius = 12
        themeHeader.layer.borderWidth = 1
        themeHeader.layer.borderColor = palette.border.cgColor
        themeHeader.clipsToBounds = true
        themeTitleLabel.font = AppFont.jp(size: 16, weight: .bold)
        themeTitleLabel.textColor = palette.text

        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            button.backgroundColor = ThemeManager.palette(for: theme).accent
        }
        updateThemeSelection()
    }

    private func updateThemeSelection() {
        let current = ThemeManager.current
        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            if theme == current {
                button.layer.borderColor = ThemeManager.palette().border.cgColor
                button.layer.shadowColor = ThemeManager.palette().border.cgColor
                button.layer.shadowOpacity = 0.25
                button.layer.shadowOffset = CGSize(width: 0, height: 2)
                button.layer.shadowRadius = 4
            } else {
                button.layer.borderColor = UIColor.clear.cgColor
                button.layer.shadowOpacity = 0
            }
        }
    }

    @objc private func openSortMenu() {
        let alert = UIAlertController(title: "並び替え", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "作成順", style: .default) { [weak self] _ in
            self?.sortOption = .created
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "名前 A→Z", style: .default) { [weak self] _ in
            self?.sortOption = .nameAsc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "名前 Z→A", style: .default) { [weak self] _ in
            self?.sortOption = .nameDesc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "単語数 少ない→多い", style: .default) { [weak self] _ in
            self?.sortOption = .countAsc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "単語数 多い→少ない", style: .default) { [weak self] _ in
            self?.sortOption = .countDesc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
        present(alert, animated: true)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func displayedSets() -> [SavedSet] {
        return displayedSetCache
    }

    private func sortedSets(_ input: [SavedSet]) -> [SavedSet] {
        switch sortOption {
        case .created:
            return input
        case .nameAsc:
            return input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return input.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .countAsc:
            return input.sorted { wordCount(for: $0) < wordCount(for: $1) }
        case .countDesc:
            return input.sorted { wordCount(for: $0) > wordCount(for: $1) }
        }
    }

    private func wordCount(for set: SavedSet) -> Int {
        return set.wordIDs.compactMap { wordsByID[$0] }.count
    }

    @objc private func handleSetRenameLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }
        let set = displayedSets()[indexPath.row]
        let alert = UIAlertController(title: "名前変更", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = set.name
            field.placeholder = "セット名"
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            if let index = self.sets.firstIndex(where: { $0.id == set.id }) {
                self.sets[index].name = name
                SetStore.saveSets(self.sets)
                self.applyFilterAndReload()
            }
        })
        present(alert, animated: true)
    }

    private func applyFilterAndReload() {
        let base: [SavedSet]
        if searchText.isEmpty {
            filteredSets = []
            base = sets
        } else {
            filteredSets = sets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            base = filteredSets
        }
        displayedSetCache = sortedSets(base)
        emptyLabel.isHidden = !displayedSetCache.isEmpty
        tableView.reloadData()
    }

    private func deleteSet(at indexPath: IndexPath) {
        let set = displayedSets()[indexPath.row]
        var allSets = SetStore.loadSets()
        if let index = allSets.firstIndex(where: { $0.id == set.id }) {
            allSets.remove(at: index)
            SetStore.saveSets(allSets)
        }
        reloadData()
    }

    private func showMoveSetSheet(for indexPath: IndexPath) {
        let set = displayedSets()[indexPath.row]
        let folders = FolderStore.loadFolders()
        let sheet = UIAlertController(title: "フォルダー移動", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "未分類", style: .default) { _ in
            self.moveSet(setID: set.id, to: nil)
        })
        folders.forEach { folder in
            sheet.addAction(UIAlertAction(title: folder.name, style: .default) { _ in
                self.moveSet(setID: set.id, to: folder.id)
            })
        }
        sheet.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        sheet.popoverPresentationController?.sourceView = tableView
        sheet.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
        present(sheet, animated: true)
    }

    private func moveSet(setID: String, to folderID: String?) {
        var allSets = SetStore.loadSets()
        guard let index = allSets.firstIndex(where: { $0.id == setID }) else { return }
        allSets[index].folderID = folderID
        SetStore.saveSets(allSets)
        reloadData()
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
            if needsWordIDMigration(from: data) {
                saveSavedWords(decoded)
            }
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            saveSavedWords(migrated)
            return migrated
        }
        return []
    }

    private func saveSavedWords(_ words: [SavedWord]) {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

extension SetEditWordsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyFilterAndReload()
    }
}

extension SetViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyFilterAndReload()
    }
}

final class SetDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let savedWordsFileName = "saved_words.json"
    private enum WordSortOption {
        case setOrder
        case englishAsc
        case englishDesc
        case japaneseAsc
        case japaneseDesc
    }
    private let setID: String
    private var setName: String = ""
    private var words: [SavedWord] = []
    private var filteredWords: [SavedWord] = []
    private var sortOption: WordSortOption = .setOrder
    private var hiddenMode: WordHiddenMode = .none
    private var hideButton: UIBarButtonItem?
    private var revealedWordIDs: Set<String> = []
    private let headerContainer = UIView()
    private let hideToggleButton = UIButton(type: .system)
    private let buttonStack = UIStackView()
    private let flipButton = UIButton(type: .system)
    private let testButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText: String = ""

    init(setID: String) {
        self.setID = setID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureButtons()
        configureTableView()
        configureEmptyLabel()
        configureSearch()
        configureNavigationItems()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    private func configureButtons() {
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        flipButton.setTitle("フリップ", for: .normal)
        flipButton.addTarget(self, action: #selector(openFlip), for: .touchUpInside)
        testButton.setTitle("テスト", for: .normal)
        testButton.addTarget(self, action: #selector(openTest), for: .touchUpInside)

        buttonStack.addArrangedSubview(flipButton)
        buttonStack.addArrangedSubview(testButton)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func configureNavigationItems() {
        let addButton = UIBarButtonItem(title: "単語追加",
                                        style: .plain,
                                        target: self,
                                        action: #selector(openEditWords))
        let editButton = UIBarButtonItem(title: "編集",
                                         style: .plain,
                                         target: self,
                                         action: #selector(toggleEditMode))
        let sortButton = UIBarButtonItem(title: "並び替え",
                                         style: .plain,
                                         target: self,
                                         action: #selector(openSortMenu))
        let renameButton = UIBarButtonItem(title: "名前変更",
                                           style: .plain,
                                           target: self,
                                           action: #selector(renameSet))
        navigationItem.rightBarButtonItems = [addButton, editButton, sortButton, renameButton]
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "ListTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "単語で検索"
        searchController.searchBar.sizeToFit()
        headerContainer.addSubview(searchController.searchBar)

        hideToggleButton.setTitle("隠す", for: .normal)
        hideToggleButton.contentHorizontalAlignment = .left
        hideToggleButton.addTarget(self, action: #selector(toggleHiddenMode), for: .touchUpInside)
        headerContainer.addSubview(hideToggleButton)

        tableView.tableHeaderView = headerContainer
        definesPresentationContext = true
    }

    private func updateHeaderLayout() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        let searchHeight = searchController.searchBar.bounds.height
        let buttonHeight: CGFloat = 36
        let headerHeight = searchHeight + buttonHeight
        header.frame = CGRect(x: 0, y: 0, width: width, height: headerHeight)
        searchController.searchBar.frame = CGRect(x: 0, y: 0, width: width, height: searchHeight)
        hideToggleButton.frame = CGRect(x: 16, y: searchHeight, width: width - 32, height: buttonHeight)
        tableView.tableHeaderView = header
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "このセットには単語がありません。"
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

    private func reloadData() {
        let sets = SetStore.loadSets()
        guard let currentSet = sets.first(where: { $0.id == setID }) else {
            navigationController?.popViewController(animated: true)
            return
        }
        setName = currentSet.name
        title = setName
        let allWords = loadSavedWords()
        let wordsByID = Dictionary(uniqueKeysWithValues: allWords.map { ($0.id, $0) })
        words = currentSet.wordIDs.compactMap { wordsByID[$0] }
        applyFilterAndReload()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedWords().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            as! ListTableViewCell
        let word = displayedWords()[indexPath.row]
        let isRevealed = revealedWordIDs.contains(word.id)
        cell.configure(word: word, hiddenMode: hiddenMode, isRevealed: isRevealed)
        cell.onFavoriteChanged = { [weak self] isFavorite in
            self?.updateWord(id: word.id, isFavorite: isFavorite)
        }
        cell.onSelectImportanceTapped = { [weak self] in
            self?.presentImportancePicker(for: word)
        }
        cell.onToggleReveal = { [weak self] in
            self?.toggleReveal(for: word.id)
        }
        return cell
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let word = displayedWords()[indexPath.row]
            removeWordFromSet(wordID: word.id)
        }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let move = UIContextualAction(style: .normal, title: "移動") { [weak self] _, _, completion in
            self?.showMoveWordSheet(for: indexPath)
            completion(true)
        }
        move.backgroundColor = .systemBlue
        let delete = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
            if let word = self?.displayedWords()[indexPath.row] {
                self?.removeWordFromSet(wordID: word.id)
            }
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, move])
    }

    @objc private func openFlip() {
        let controller = FlipViewController()
        controller.presetWords = words
        controller.title = "\(setName) フリップ"
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openTest() {
        let controller = TestViewController()
        controller.presetWords = words
        controller.title = "\(setName) テスト"
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func toggleEditMode() {
        let shouldEdit = !tableView.isEditing
        tableView.setEditing(shouldEdit, animated: true)
        if let editButton = navigationItem.rightBarButtonItems?.first(where: { $0.title == "編集" || $0.title == "完了" }) {
            editButton.title = shouldEdit ? "完了" : "編集"
        }
    }

    @objc private func openEditWords() {
        let controller = SetEditWordsViewController(setID: setID)
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func renameSet() {
        let alert = UIAlertController(title: "名前変更", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] field in
            field.text = self?.setName
            field.placeholder = "セット名"
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            var sets = SetStore.loadSets()
            if let index = sets.firstIndex(where: { $0.id == self.setID }) {
                sets[index].name = name
                SetStore.saveSets(sets)
                self.setName = name
                self.title = name
            }
        })
        present(alert, animated: true)
    }

    @objc private func openSortMenu() {
        let alert = UIAlertController(title: "並び替え", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "セット順", style: .default) { [weak self] _ in
            self?.sortOption = .setOrder
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "英語 A→Z", style: .default) { [weak self] _ in
            self?.sortOption = .englishAsc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "英語 Z→A", style: .default) { [weak self] _ in
            self?.sortOption = .englishDesc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "日本語 あ→ん", style: .default) { [weak self] _ in
            self?.sortOption = .japaneseAsc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "日本語 ん→あ", style: .default) { [weak self] _ in
            self?.sortOption = .japaneseDesc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first(where: { $0.title == "並び替え" })
        present(alert, animated: true)
    }

    private func updateHiddenButtonTitle() {
        let title = hiddenMode == .none ? "隠す" : "表示"
        hideToggleButton.setTitle(title, for: .normal)
    }

    @objc private func toggleHiddenMode() {
        if hiddenMode != .none {
            hiddenMode = .none
            revealedWordIDs.removeAll()
            updateHiddenButtonTitle()
            tableView.reloadData()
            return
        }

        let alert = UIAlertController(title: "隠す項目", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "英語を隠す", style: .default) { [weak self] _ in
            self?.hiddenMode = .english
            self?.revealedWordIDs.removeAll()
            self?.updateHiddenButtonTitle()
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "日本語を隠す", style: .default) { [weak self] _ in
            self?.hiddenMode = .japanese
            self?.revealedWordIDs.removeAll()
            self?.updateHiddenButtonTitle()
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = hideButton
        present(alert, animated: true)
    }

    private func displayedWords() -> [SavedWord] {
        let base: [SavedWord]
        if searchText.isEmpty {
            base = words
        } else {
            base = filteredWords
        }
        return sortedWords(base)
    }

    private func sortedWords(_ input: [SavedWord]) -> [SavedWord] {
        switch sortOption {
        case .setOrder:
            return input
        case .englishAsc:
            return input.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
        case .englishDesc:
            return input.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedDescending }
        case .japaneseAsc:
            return input.sorted { $0.japanese.localizedCaseInsensitiveCompare($1.japanese) == .orderedAscending }
        case .japaneseDesc:
            return input.sorted { $0.japanese.localizedCaseInsensitiveCompare($1.japanese) == .orderedDescending }
        }
    }

    private func applyFilterAndReload() {
        if searchText.isEmpty {
            filteredWords = []
        } else {
            filteredWords = words.filter {
                $0.english.localizedCaseInsensitiveContains(searchText)
                    || $0.japanese.localizedCaseInsensitiveContains(searchText)
            }
        }
        let displayed = displayedWords()
        emptyLabel.isHidden = !displayed.isEmpty
        flipButton.isEnabled = !displayed.isEmpty
        testButton.isEnabled = !displayed.isEmpty
        tableView.reloadData()
    }

    private func removeWordFromSet(wordID: String) {
        var sets = SetStore.loadSets()
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return }
        sets[index].wordIDs.removeAll { $0 == wordID }
        SetStore.saveSets(sets)
        reloadData()
    }

    private func showMoveWordSheet(for indexPath: IndexPath) {
        let word = displayedWords()[indexPath.row]
        let sets = SetStore.loadSets()
        let targets = sets.filter { $0.id != setID }
        guard !targets.isEmpty else {
            let alert = UIAlertController(title: "移動先がありません",
                                          message: "他のセットを作成してください。",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let sheet = UIAlertController(title: "移動先を選択", message: nil, preferredStyle: .actionSheet)
        targets.forEach { target in
            sheet.addAction(UIAlertAction(title: target.name, style: .default) { [weak self] _ in
                self?.moveWord(wordID: word.id, to: target.id)
            })
        }
        sheet.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        sheet.popoverPresentationController?.sourceView = tableView
        sheet.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
        present(sheet, animated: true)
    }

    private func moveWord(wordID: String, to targetSetID: String) {
        var sets = SetStore.loadSets()
        guard let sourceIndex = sets.firstIndex(where: { $0.id == setID }),
              let targetIndex = sets.firstIndex(where: { $0.id == targetSetID }) else { return }
        sets[sourceIndex].wordIDs.removeAll { $0 == wordID }
        if !sets[targetIndex].wordIDs.contains(wordID) {
            sets[targetIndex].wordIDs.append(wordID)
        }
        SetStore.saveSets(sets)
        reloadData()
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
            if needsWordIDMigration(from: data) {
                saveSavedWords(decoded)
            }
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            saveSavedWords(migrated)
            return migrated
        }
        return []
    }

    private func saveSavedWords(_ words: [SavedWord]) {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func updateWord(id: String, isFavorite: Bool? = nil, importanceLevel: Int? = nil) {
        var allWords = loadSavedWords()
        guard let index = allWords.firstIndex(where: { $0.id == id }) else { return }
        var word = allWords[index]
        if let isFavorite {
            word.isFavorite = isFavorite
        }
        if let importanceLevel {
            word.importanceLevel = importanceLevel
        }
        allWords[index] = word
        saveSavedWords(allWords)
        if let localIndex = words.firstIndex(where: { $0.id == id }) {
            words[localIndex] = word
        }
    }

    private func presentImportancePicker(for word: SavedWord) {
        let alert = UIAlertController(title: "重要度", message: nil, preferredStyle: .actionSheet)
        for level in 1...5 {
            alert.addAction(UIAlertAction(title: "Lv\(level)", style: .default) { [weak self] _ in
                self?.updateWord(id: word.id, importanceLevel: level)
                if let indexPath = self?.indexPathForWord(id: word.id),
                   let cell = self?.tableView.cellForRow(at: indexPath) as? ListTableViewCell {
                    cell.updateImportance(level: level)
                }
            })
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        if let popover = alert.popoverPresentationController,
           let indexPath = indexPathForWord(id: word.id),
           let cell = tableView.cellForRow(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(alert, animated: true)
    }

    private func toggleReveal(for id: String) {
        guard hiddenMode != .none else { return }
        if revealedWordIDs.contains(id) {
            revealedWordIDs.remove(id)
        } else {
            revealedWordIDs.insert(id)
        }
        if let indexPath = indexPathForWord(id: id) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private func indexPathForWord(id: String) -> IndexPath? {
        let current = displayedWords()
        guard let row = current.firstIndex(where: { $0.id == id }) else { return nil }
        return IndexPath(row: row, section: 0)
    }
}

extension SetDetailViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        applyFilterAndReload()
    }
}

final class SetCreateViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let savedWordsFileName = "saved_words.json"
    private let folderID: String?
    private var words: [SavedWord] = []
    private var selectedWordIDs: Set<String> = []
    private let nameTextField = UITextField()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()

    init(folderID: String?) {
        self.folderID = folderID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        folderID = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "セット追加"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(saveSet))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "キャンセル",
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(cancel))

        configureNameField()
        configureTableView()
        configureEmptyLabel()
        loadWords()
    }

    private func configureNameField() {
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.borderStyle = .roundedRect
        nameTextField.placeholder = "セット名"
        view.addSubview(nameTextField)

        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nameTextField.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.register(UINib(nibName: "ListTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "単語がありません。\n先に単語を追加してください。"
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

    private func loadWords() {
        words = loadSavedWords()
        emptyLabel.isHidden = !words.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !words.isEmpty
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return words.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            as! ListTableViewCell
        let word = words[indexPath.row]
        cell.englishLabel.text = word.english
        cell.japaneseLabel.text = word.japanese
        cell.applyHiddenMode(.none, isRevealed: false)
        cell.accessoryType = selectedWordIDs.contains(word.id) ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let word = words[indexPath.row]
        if selectedWordIDs.contains(word.id) {
            selectedWordIDs.remove(word.id)
        } else {
            selectedWordIDs.insert(word.id)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    @objc private func saveSet() {
        let name = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            showAlert(title: "入力エラー", message: "セット名を入力してください。")
            return
        }
        guard !selectedWordIDs.isEmpty else {
            showAlert(title: "選択エラー", message: "単語を1つ以上選択してください。")
            return
        }
        var sets = SetStore.loadSets()
        let orderedIDs = words.filter { selectedWordIDs.contains($0.id) }.map { $0.id }
        let newSet = SavedSet(name: name, wordIDs: orderedIDs, folderID: folderID)
        sets.append(newSet)
        SetStore.saveSets(sets)
        navigationController?.popViewController(animated: true)
    }

    @objc private func cancel() {
        navigationController?.popViewController(animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
            if needsWordIDMigration(from: data) {
                saveSavedWords(decoded)
            }
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            saveSavedWords(migrated)
            return migrated
        }
        return []
    }

    private func saveSavedWords(_ words: [SavedWord]) {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class SetEditWordsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let savedWordsFileName = "saved_words.json"
    private enum WordSortOption {
        case created
        case englishAsc
        case englishDesc
        case japaneseAsc
        case japaneseDesc
    }
    private let setID: String
    private var words: [SavedWord] = []
    private var filteredWords: [SavedWord] = []
    private var selectedWordIDs: Set<String> = []
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchText: String = ""
    private var sortOption: WordSortOption = .created

    init(setID: String) {
        self.setID = setID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "単語を編集"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "保存",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(saveChanges))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "並び替え",
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(openSortMenu))
        configureTableView()
        configureEmptyLabel()
        configureSearch()
        loadData()
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "ListTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "単語で検索"
        tableView.tableHeaderView = searchController.searchBar
        definesPresentationContext = true
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "単語がありません。\n先に単語を追加してください。"
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

    private func loadData() {
        words = loadSavedWords()
        let sets = SetStore.loadSets()
        if let currentSet = sets.first(where: { $0.id == setID }) {
            selectedWordIDs = Set(currentSet.wordIDs)
        }
        applyFilterAndReload()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedWords().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            as! ListTableViewCell
        let word = displayedWords()[indexPath.row]
        cell.englishLabel.text = word.english
        cell.japaneseLabel.text = word.japanese
        cell.applyHiddenMode(.none, isRevealed: false)
        cell.accessoryType = selectedWordIDs.contains(word.id) ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let word = words[indexPath.row]
        if selectedWordIDs.contains(word.id) {
            selectedWordIDs.remove(word.id)
        } else {
            selectedWordIDs.insert(word.id)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    @objc private func openSortMenu() {
        let alert = UIAlertController(title: "並び替え", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "作成順", style: .default) { [weak self] _ in
            self?.sortOption = .created
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "英語 A→Z", style: .default) { [weak self] _ in
            self?.sortOption = .englishAsc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "英語 Z→A", style: .default) { [weak self] _ in
            self?.sortOption = .englishDesc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "日本語 あ→ん", style: .default) { [weak self] _ in
            self?.sortOption = .japaneseAsc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "日本語 ん→あ", style: .default) { [weak self] _ in
            self?.sortOption = .japaneseDesc
            self?.applyFilterAndReload()
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        present(alert, animated: true)
    }

    private func displayedWords() -> [SavedWord] {
        let base: [SavedWord]
        if searchText.isEmpty {
            base = words
        } else {
            base = filteredWords
        }
        return sortedWords(base)
    }

    private func sortedWords(_ input: [SavedWord]) -> [SavedWord] {
        switch sortOption {
        case .created:
            return input
        case .englishAsc:
            return input.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
        case .englishDesc:
            return input.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedDescending }
        case .japaneseAsc:
            return input.sorted { $0.japanese.localizedCaseInsensitiveCompare($1.japanese) == .orderedAscending }
        case .japaneseDesc:
            return input.sorted { $0.japanese.localizedCaseInsensitiveCompare($1.japanese) == .orderedDescending }
        }
    }

    private func applyFilterAndReload() {
        if searchText.isEmpty {
            filteredWords = []
        } else {
            filteredWords = words.filter {
                $0.english.localizedCaseInsensitiveContains(searchText)
                    || $0.japanese.localizedCaseInsensitiveContains(searchText)
            }
        }
        emptyLabel.isHidden = !displayedWords().isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !words.isEmpty
        tableView.reloadData()
    }

    @objc private func saveChanges() {
        guard !selectedWordIDs.isEmpty else {
            let alert = UIAlertController(title: "選択エラー",
                                          message: "単語を1つ以上選択してください。",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        var sets = SetStore.loadSets()
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return }
        let orderedIDs = words.filter { selectedWordIDs.contains($0.id) }.map { $0.id }
        sets[index].wordIDs = orderedIDs
        SetStore.saveSets(sets)
        navigationController?.popViewController(animated: true)
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
            if needsWordIDMigration(from: data) {
                saveSavedWords(decoded)
            }
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil) }
            saveSavedWords(migrated)
            return migrated
        }
        return []
    }

    private func saveSavedWords(_ words: [SavedWord]) {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
