import UIKit

final class PlaylistListViewController: BaseViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private var playlists: [Playlist] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Playlist"
        configureUI()
        loadPlaylists()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPlaylists()
        tableView.reloadData()
    }

    override func applyBaseTheme() {
        super.applyBaseTheme()
        let palette = ThemeManager.palette()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        emptyLabel.applyMankiTextStyle(.body, color: palette.mutedText, alignment: .center, numberOfLines: 0)
    }

    private func configureUI() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "追加",
            style: .plain,
            target: self,
            action: #selector(addPlaylist)
        )

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RetroSummaryCell.self, forCellReuseIdentifier: RetroSummaryCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 124

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "まだ Playlist がありません。\n好きな曲や気分ごとに作成できます。"

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24))
        ])
    }

    private func loadPlaylists() {
        playlists = PlaylistStore.loadPlaylists()
        emptyLabel.isHidden = !playlists.isEmpty
    }

    @objc private func addPlaylist() {
        let controller = PlaylistEditorViewController(onSavePlaylist: { [weak self] playlist in
            guard let self else { return }
            var current = PlaylistStore.loadPlaylists()
            current.insert(playlist, at: 0)
            PlaylistStore.savePlaylists(current)
            self.loadPlaylists()
            self.tableView.reloadData()
        })
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension PlaylistListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        playlists.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RetroSummaryCell.reuseIdentifier, for: indexPath) as! RetroSummaryCell
        let playlist = playlists[indexPath.row]
        let songCount = playlist.songs.count
        let cardCount = playlist.allCards.count
        cell.configure(
            title: playlist.title,
            subtitle: playlist.description.isEmpty ? "曲と感情タグから覚える単語セット" : playlist.description,
            meta: "\(songCount)曲 / \(cardCount)カード",
            emotionTag: playlist.emotionTheme
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller = PlaylistDetailViewController(playlistID: playlists[indexPath.row].id)
        navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        playlists.remove(at: indexPath.row)
        PlaylistStore.savePlaylists(playlists)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        emptyLabel.isHidden = !playlists.isEmpty
    }
}
