import UIKit

final class ImportPreviewViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var session: ImportSession
    var onConfirm: (([ImportRow]) -> Void)?

    private var resolvedRows: [ImportRow] {
        session.rows.filter { $0.isResolved }
    }

    private var unclassifiedRows: [ImportRow] {
        session.rows.filter { !$0.isResolved }
    }

    init(session: ImportSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.session = ImportSession(sourceText: "", rows: [])
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "取り込み確認"
        view.backgroundColor = .systemBackground
        configureNavigation()
        configureTable()
    }

    private func configureNavigation() {
        // 再パースと確定ボタン
        let reparse = UIBarButtonItem(title: "再パース",
                                      style: .plain,
                                      target: self,
                                      action: #selector(reparseTapped))
        let save = UIBarButtonItem(title: "確定",
                                   style: .done,
                                   target: self,
                                   action: #selector(confirmTapped))
        let edit = editButtonItem
        navigationItem.leftBarButtonItem = reparse
        navigationItem.rightBarButtonItems = [save, edit]
        navigationItem.backButtonTitle = "戻る"

        let deleteSelected = UIBarButtonItem(title: "選択削除",
                                             style: .plain,
                                             target: self,
                                             action: #selector(deleteSelectedTapped))
        toolbarItems = [deleteSelected]
        navigationController?.isToolbarHidden = true
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(ImportRowCell.self, forCellReuseIdentifier: ImportRowCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.estimatedRowHeight = 64
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        navigationController?.setToolbarHidden(!editing, animated: true)
    }

    @objc private func reparseTapped() {
        // 同じ sourceText から再パース
        let rows = ImportParser.parse(text: session.sourceText, mode: session.mode)
        session.rows = rows
        tableView.reloadData()
    }

    @objc private func deleteSelectedTapped() {
        // 複数選択削除
        guard let selected = tableView.indexPathsForSelectedRows else { return }
        let idsToDelete = selected.compactMap { indexPath -> UUID? in
            row(at: indexPath)?.id
        }
        session.rows.removeAll { idsToDelete.contains($0.id) }
        tableView.reloadData()
    }

    @objc private func confirmTapped() {
        // 確定行のみを返す
        let rows = session.rows.filter { $0.isResolved }
        guard !rows.isEmpty else {
            let alert = UIAlertController(title: "未確定",
                                          message: "確定できる行がありません。編集してから確定してください。",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        onConfirm?(rows)
    }

    private func row(at indexPath: IndexPath) -> ImportRow? {
        if indexPath.section == 0 {
            return resolvedRows[safe: indexPath.row]
        } else {
            return unclassifiedRows[safe: indexPath.row]
        }
    }

    private func updateRow(_ row: ImportRow) {
        if let index = session.rows.firstIndex(where: { $0.id == row.id }) {
            session.rows[index] = row
        }
    }

    private func editValue(for row: ImportRow, isTerm: Bool) {
        let title = isTerm ? "英単語" : "日本語"
        let alert = UIAlertController(title: title, message: "値を編集してください", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = isTerm ? row.term : row.meaning
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self else { return }
            let text = alert.textFields?.first?.text ?? ""
            var updated = row
            if isTerm {
                updated.term = text
            } else {
                updated.meaning = text
            }
            updated.status = updated.isResolved ? .confirmed : .unclassified
            self.updateRow(updated)
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }
}

extension ImportPreviewViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return resolvedRows.count }
        return unclassifiedRows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return "候補" }
        return "未分類"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ImportRowCell.reuseID, for: indexPath) as? ImportRowCell else {
            return UITableViewCell()
        }
        guard let row = row(at: indexPath) else { return cell }
        cell.configure(term: row.term, meaning: row.meaning, isUnclassified: !row.isResolved)
        cell.onTermTapped = { [weak self] in
            self?.editValue(for: row, isTerm: true)
        }
        cell.onMeaningTapped = { [weak self] in
            self?.editValue(for: row, isTerm: false)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let row = row(at: indexPath) {
                session.rows.removeAll { $0.id == row.id }
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        }
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0
    }

    func tableView(_ tableView: UITableView,
                   moveRowAt sourceIndexPath: IndexPath,
                   to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.section == 0, destinationIndexPath.section == 0 else {
            tableView.reloadData()
            return
        }
        var resolved = resolvedRows
        let moved = resolved.remove(at: sourceIndexPath.row)
        resolved.insert(moved, at: destinationIndexPath.row)
        let unresolved = unclassifiedRows
        session.rows = resolved + unresolved
        tableView.reloadData()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
