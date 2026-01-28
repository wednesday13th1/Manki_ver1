//
//  ListTableViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2025/12/28.
//

import UIKit

class ListTableViewController: UITableViewController {
    private var wordArray: [SavedWord] = []
    private let savedWordsFileName = "saved_words.json"
    private var hiddenMode: WordHiddenMode = .none
    private var hideButton: UIBarButtonItem?
    private var revealedWordIDs: Set<String> = []
    var startEditing = false
    var hideTestAndAdd = false

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "ListTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        let backItem = UIBarButtonItem(title: "戻る",
                                       style: .plain,
                                       target: self,
                                       action: #selector(openWordMenu))
        let hideItem = UIBarButtonItem(title: "隠す",
                                       style: .plain,
                                       target: self,
                                       action: #selector(toggleHiddenMode))
        navigationItem.leftBarButtonItems = [backItem, hideItem]
        hideButton = hideItem
        if hideTestAndAdd {
            navigationItem.rightBarButtonItems = nil
        } else if let addItem = navigationItem.rightBarButtonItem {
            let testItem = UIBarButtonItem(title: "テスト",
                                           style: .plain,
                                           target: self,
                                           action: #selector(openTest))
            navigationItem.rightBarButtonItems = [testItem, addItem]
        }
        // Do any additional setup after loading the view.
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
            return decoded
        }

        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        if !legacy.isEmpty {
            let migrated = legacy.map { SavedWord(english: $0["english"] ?? "",
                                                  japanese: $0["japanese"] ?? "",
                                                  illustrationScenario: nil,
                                                  illustrationImageFileName: nil)}
            wordArray = migrated
            saveSavedWords()
            return migrated
        }
        return []
    }

    private func saveSavedWords() {
        let fileURL = savedWordsFileURL()
        guard let data = try? JSONEncoder().encode(wordArray) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        wordArray = loadSavedWords()
        tableView.reloadData()
        if hideTestAndAdd {
            navigationItem.rightBarButtonItems = nil
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if startEditing {
            tableView.setEditing(true, animated: true)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wordArray.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) ->
    UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        as! ListTableViewCell

        let word = wordArray[indexPath.row]
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

    // 1) Allow swipe-to-delete.
    override func tableView(_ tableView: UITableView,
                            canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // 2) Handle deletion.
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let removedWord = wordArray[indexPath.row]
            wordArray.remove(at: indexPath.row)
            saveSavedWords()
            removeWordFromSets(wordID: removedWord.id)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    // 3) Rename delete button (optional).
    override func tableView(_ tableView: UITableView,
                            titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "削除"
    }

    private func updateHiddenButtonTitle() {
        let title = hiddenMode == .none ? "隠す" : "表示"
        hideButton?.title = title
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
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))
        alert.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        present(alert, animated: true, completion: nil)
    }

    @objc private func openTest() {
        let controller = QuizViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openWordMenu() {
        if let nav = navigationController,
           let target = nav.viewControllers.last(where: { $0 is SetViewController }) {
            nav.popToViewController(target, animated: true)
            return
        }
        navigationController?.popViewController(animated: true)
    }

    private func removeWordFromSets(wordID: String) {
        var sets = SetStore.loadSets()
        var updated = false
        for index in sets.indices {
            let beforeCount = sets[index].wordIDs.count
            sets[index].wordIDs.removeAll { $0 == wordID }
            if sets[index].wordIDs.count != beforeCount {
                updated = true
            }
        }
        if updated {
            SetStore.saveSets(sets)
        }
    }

    private func updateWord(id: String, isFavorite: Bool? = nil, importanceLevel: Int? = nil) {
        guard let index = wordArray.firstIndex(where: { $0.id == id }) else { return }
        var word = wordArray[index]
        if let isFavorite {
            word.isFavorite = isFavorite
        }
        if let importanceLevel {
            word.importanceLevel = importanceLevel
        }
        wordArray[index] = word
        saveSavedWords()
    }

    private func presentImportancePicker(for word: SavedWord) {
        let alert = UIAlertController(title: "重要度", message: nil, preferredStyle: .actionSheet)
        for level in 1...5 {
            alert.addAction(UIAlertAction(title: "Lv\(level)", style: .default) { [weak self] _ in
                self?.updateWord(id: word.id, importanceLevel: level)
                if let index = self?.wordArray.firstIndex(where: { $0.id == word.id }) {
                    self?.wordArray[index].importanceLevel = level
                }
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

    private func indexPathForWord(id: String) -> IndexPath? {
        guard let row = wordArray.firstIndex(where: { $0.id == id }) else { return nil }
        return IndexPath(row: row, section: 0)
    }

    private func toggleReveal(for id: String) {
        guard hiddenMode != .none else { return }
        if revealedWordIDs.contains(id) {
            revealedWordIDs.remove(id)
        } else {
            revealedWordIDs.insert(id)
        }
        if let index = wordArray.firstIndex(where: { $0.id == id }) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
}
