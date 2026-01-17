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

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "ListTableViewCell", bundle: nil),
                           forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        let backItem = UIBarButtonItem(title: "単語",
                                       style: .plain,
                                       target: self,
                                       action: #selector(openWordMenu))
        let hideItem = UIBarButtonItem(title: "隠す",
                                       style: .plain,
                                       target: self,
                                       action: #selector(toggleHiddenMode))
        navigationItem.leftBarButtonItems = [backItem, hideItem]
        hideButton = hideItem
        if let addItem = navigationItem.rightBarButtonItem {
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
                                                  illustrationScenario: nil) }
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

        let nowIndexPathDictionary = wordArray[indexPath.row]
        cell.englishLabel.text = nowIndexPathDictionary.english
        cell.japaneseLabel.text = nowIndexPathDictionary.japanese
        cell.applyHiddenMode(hiddenMode)

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
            wordArray.remove(at: indexPath.row)
            saveSavedWords()
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
            updateHiddenButtonTitle()
            tableView.reloadData()
            return
        }

        let alert = UIAlertController(title: "隠す項目", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "英語を隠す", style: .default) { [weak self] _ in
            self?.hiddenMode = .english
            self?.updateHiddenButtonTitle()
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "日本語を隠す", style: .default) { [weak self] _ in
            self?.hiddenMode = .japanese
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
        navigationController?.popToRootViewController(animated: true)
    }
}
