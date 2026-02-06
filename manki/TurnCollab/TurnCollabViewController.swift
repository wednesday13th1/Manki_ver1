import UIKit
import Combine

final class TurnCollabViewController: UIViewController {
    private let viewModel = TurnRoomViewModel()
    private var cancellables: Set<AnyCancellable> = []

    private let wordField = UITextField()
    private let hostButton = UIButton(type: .system)
    private let joinButton = UIButton(type: .system)
    private let startButton = UIButton(type: .system)
    private let sharePlayInfoLabel = UILabel()
    private let peersTable = UITableView(frame: .zero, style: .insetGrouped)
    private let connectedLabel = UILabel()
    private let turnLabel = UILabel()
    private let inputField = UITextField()
    private let submitButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureNavigation()
        configureKeyboardDismiss()
        configureUI()
        bindViewModel()
    }

    private func configureNavigation() {
        title = "コラボ"
        ThemeManager.applyNavigationAppearance(to: navigationController)
        let backItem = UIBarButtonItem(title: "戻る", style: .plain, target: self, action: #selector(closeSelf))
        navigationItem.leftBarButtonItem = backItem
    }

    private func configureKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func configureUI() {
        wordField.translatesAutoresizingMaskIntoConstraints = false
        wordField.borderStyle = .roundedRect
        wordField.placeholder = "お題（英単語）"
        wordField.font = AppFont.jp(size: 14)

        hostButton.translatesAutoresizingMaskIntoConstraints = false
        hostButton.setTitle("SharePlay開始", for: .normal)
        hostButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        hostButton.addTarget(self, action: #selector(hostTapped), for: .touchUpInside)

        joinButton.translatesAutoresizingMaskIntoConstraints = false
        joinButton.setTitle("参加待機", for: .normal)
        joinButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)

        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("開始", for: .normal)
        startButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        peersTable.translatesAutoresizingMaskIntoConstraints = false
        peersTable.dataSource = self
        peersTable.delegate = self
        peersTable.allowsSelection = false

        sharePlayInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        sharePlayInfoLabel.numberOfLines = 0
        sharePlayInfoLabel.font = AppFont.jp(size: 12)
        sharePlayInfoLabel.textColor = .secondaryLabel
        sharePlayInfoLabel.text = "SharePlay中の参加者に同期されます。ホストは「SharePlay開始」、参加者は「参加待機」を押してください。"

        connectedLabel.translatesAutoresizingMaskIntoConstraints = false
        connectedLabel.numberOfLines = 0
        connectedLabel.font = AppFont.jp(size: 13)

        turnLabel.translatesAutoresizingMaskIntoConstraints = false
        turnLabel.numberOfLines = 0
        turnLabel.font = AppFont.jp(size: 14, weight: .bold)

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.borderStyle = .roundedRect
        inputField.placeholder = "入力（テキスト）"
        inputField.font = AppFont.jp(size: 14)

        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.setTitle("送信", for: .normal)
        submitButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0
        statusLabel.font = AppFont.jp(size: 12)
        statusLabel.textColor = .secondaryLabel

        let buttonStack = UIStackView(arrangedSubviews: [hostButton, joinButton, startButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let inputStack = UIStackView(arrangedSubviews: [inputField, submitButton])
        inputStack.axis = .horizontal
        inputStack.spacing = 8
        inputStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(wordField)
        view.addSubview(buttonStack)
        view.addSubview(sharePlayInfoLabel)
        view.addSubview(peersTable)
        view.addSubview(connectedLabel)
        view.addSubview(turnLabel)
        view.addSubview(inputStack)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            wordField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            wordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            wordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            buttonStack.topAnchor.constraint(equalTo: wordField.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: wordField.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: wordField.trailingAnchor),

            sharePlayInfoLabel.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 8),
            sharePlayInfoLabel.leadingAnchor.constraint(equalTo: wordField.leadingAnchor),
            sharePlayInfoLabel.trailingAnchor.constraint(equalTo: wordField.trailingAnchor),

            peersTable.topAnchor.constraint(equalTo: sharePlayInfoLabel.bottomAnchor, constant: 8),
            peersTable.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            peersTable.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            peersTable.heightAnchor.constraint(lessThanOrEqualToConstant: 160),

            connectedLabel.topAnchor.constraint(equalTo: peersTable.bottomAnchor, constant: 8),
            connectedLabel.leadingAnchor.constraint(equalTo: wordField.leadingAnchor),
            connectedLabel.trailingAnchor.constraint(equalTo: wordField.trailingAnchor),

            turnLabel.topAnchor.constraint(equalTo: connectedLabel.bottomAnchor, constant: 8),
            turnLabel.leadingAnchor.constraint(equalTo: wordField.leadingAnchor),
            turnLabel.trailingAnchor.constraint(equalTo: wordField.trailingAnchor),

            inputStack.topAnchor.constraint(equalTo: turnLabel.bottomAnchor, constant: 8),
            inputStack.leadingAnchor.constraint(equalTo: wordField.leadingAnchor),
            inputStack.trailingAnchor.constraint(equalTo: wordField.trailingAnchor),

            submitButton.widthAnchor.constraint(equalToConstant: 70),

            statusLabel.topAnchor.constraint(equalTo: inputStack.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: wordField.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: wordField.trailingAnchor)
        ])

        let peersPreferredHeight = peersTable.heightAnchor.constraint(equalToConstant: 140)
        peersPreferredHeight.priority = .defaultHigh
        peersPreferredHeight.isActive = true
        let peersMinHeight = peersTable.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        peersMinHeight.priority = .defaultLow
        peersMinHeight.isActive = true
    }

    private func bindViewModel() {
        viewModel.$participantLabels
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.peersTable.reloadData()
            }
            .store(in: &cancellables)

        viewModel.$participantLabels
            .receive(on: RunLoop.main)
            .sink { [weak self] labels in
                if labels.isEmpty {
                    self?.connectedLabel.text = "SharePlay未接続"
                } else {
                    let names = labels.joined(separator: ", ")
                    self?.connectedLabel.text = "参加者: \(names)"
                }
            }
            .store(in: &cancellables)

        viewModel.$currentTurn
            .receive(on: RunLoop.main)
            .sink { [weak self] turn in
                guard let turn else {
                    self?.turnLabel.text = ""
                    return
                }
                self?.turnLabel.text = "Turn \(turn.turnIndex + 1)/\(turn.totalTurns) - 次: \(turn.currentPlayerID)"
            }
            .store(in: &cancellables)

        viewModel.$statusText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.statusLabel.text = text
            }
            .store(in: &cancellables)
    }

    @objc private func hostTapped() {
        let word = (wordField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        viewModel.hostRoom(word: word, turnDurationSec: 60)
    }

    @objc private func joinTapped() {
        viewModel.joinRoom()
    }

    @objc private func startTapped() {
        viewModel.startGame()
    }

    @objc private func submitTapped() {
        let text = (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.submit(text: text)
        inputField.text = ""
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func closeSelf() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension TurnCollabViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.participantLabels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell") ?? UITableViewCell(style: .default, reuseIdentifier: "peerCell")
        cell.textLabel?.text = viewModel.participantLabels[indexPath.row]
        cell.textLabel?.font = AppFont.jp(size: 14)
        return cell
    }
}
