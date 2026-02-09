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
    private let tapGesture = UITapGestureRecognizer()
    private let emptyLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)
    private let searchContainer = UIView()
    private var searchText: String = ""
    private let themeHeader = UIView()
    private let themeTitleLabel = UILabel()
    private let themeStack = UIStackView()
    private var themeButtons: [UIButton] = []
    private var themeObserver: NSObjectProtocol?
    private let themeHeaderHeight: CGFloat = 120
    private let retroShellView = UIView()
    private let retroScreenView = UIView()
    private let retroKeypadView = UIView()
    private let retroKeypadGrid = UIStackView()
    private let retroKeypadRowTop = UIStackView()
    private let retroKeypadRowBottom = UIStackView()
    private var retroKeyButtons: [UIButton] = []
    private let retroFolderButton = UIButton(type: .system)
    private let retroWordButton = UIButton(type: .system)
    private let retroSortButton = UIButton(type: .system)
    private let retroAddButton = UIButton(type: .system)
    private let retroAntennaView = UIView()
    private let retroAntennaTipView = UIView()
    private let retroSpeakerView = UIView()
    private let retroClickWheelView = UIView()
    private let retroClickWheelCenterView = UIView()
    private let retroClickWheelVerticalDivider = UIView()
    private let retroClickWheelHorizontalDivider = UIView()
    private let retroClickWheelFolderButton = UIButton(type: .system)
    private let retroClickWheelWordButton = UIButton(type: .system)
    private let retroBadgeLabel = UILabel()
    private let headerContainer = UIView()
    private let keyboardDismissTap = UITapGestureRecognizer()
    private var retroShellBottomConstraint: NSLayoutConstraint?
    private var keypadTopConstraint: NSLayoutConstraint?
    private var clickWheelTopConstraint: NSLayoutConstraint?
    private var clickWheelBottomConstraint: NSLayoutConstraint?
    private var screenBottomConstraint: NSLayoutConstraint?
    private var keyboardObservers: [NSObjectProtocol] = []
    private let hideToggleButton = UIButton(type: .system)
    private var renameGesture: UILongPressGestureRecognizer?
    private var isHandlingSelection = false
    private var wordMenuOverlay: UIControl?
    private var wordMenuContainer: UIView?
    private var wordMenuTitleLabel: UILabel?
    private var wordMenuButtons: [UIButton] = []
    private let shareManager = SetSharePlayManager.shared

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
        configureKeyboardDismiss()
        configureKeyboardObservers()
        configureRetroShell()
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
        setupShareManager()

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
                                            action: #selector(openFolderView))
        navigationItem.leftBarButtonItems = [foldersButton, wordsButton]
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
        shareManager.stop()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = true
        tableView.allowsSelectionDuringEditing = true
        shareManager.start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderLayout()
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
        tableView.rowHeight = 72
        tableView.delaysContentTouches = false
        tableView.keyboardDismissMode = .onDrag
        retroScreenView.addSubview(searchContainer)
        retroScreenView.addSubview(tableView)

        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchController.searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchController.searchBar)
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleSetRenameLongPress(_:)))
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesBegan = false
        gesture.delegate = self
        tableView.addGestureRecognizer(gesture)
        renameGesture = gesture
        tapGesture.addTarget(self, action: #selector(handleTableTap(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delaysTouchesBegan = false
        tapGesture.delegate = self
        tapGesture.require(toFail: tableView.panGestureRecognizer)
        tableView.addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: retroScreenView.topAnchor, constant: AppSpacing.s(12)),
            searchContainer.leadingAnchor.constraint(equalTo: retroScreenView.leadingAnchor, constant: AppSpacing.s(12)),
            searchContainer.trailingAnchor.constraint(equalTo: retroScreenView.trailingAnchor, constant: -AppSpacing.s(12)),

            searchController.searchBar.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: AppSpacing.s(6)),
            searchController.searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: AppSpacing.s(6)),
            searchController.searchBar.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -AppSpacing.s(6)),
            searchController.searchBar.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: -AppSpacing.s(6)),

            tableView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: AppSpacing.s(8)),
            tableView.leadingAnchor.constraint(equalTo: retroScreenView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: retroScreenView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: retroScreenView.bottomAnchor),
        ])
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc private func handleTableTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else {
            view.endEditing(true)
            return
        }
        view.endEditing(true)
        handleSelection(at: indexPath)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func handleSelection(at indexPath: IndexPath) {
        guard !isHandlingSelection else { return }
        guard indexPath.row < displayedSetCache.count else { return }
        isHandlingSelection = true
        let set = displayedSetCache[indexPath.row]
        let controller = SetDetailViewController(setID: set.id)
        if let nav = navigationController {
            nav.pushViewController(controller, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
        DispatchQueue.main.async { [weak self] in
            self?.isHandlingSelection = false
        }
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "セットがありません。\n右上の「追加」で作成できます。"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        retroScreenView.addSubview(emptyLabel)
        retroScreenView.bringSubviewToFront(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: retroScreenView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: retroScreenView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: retroScreenView.leadingAnchor, constant: AppSpacing.s(20)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: retroScreenView.trailingAnchor, constant: -AppSpacing.s(20)),
        ])
    }

    private func configureSearch() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "セット名で検索"
        searchController.searchBar.sizeToFit()
        definesPresentationContext = true
    }

    private func configureKeyboardDismiss() {
        keyboardDismissTap.addTarget(self, action: #selector(dismissKeyboard))
        keyboardDismissTap.cancelsTouchesInView = false
        keyboardDismissTap.delegate = self
        view.addGestureRecognizer(keyboardDismissTap)
    }

    private func configureKeyboardObservers() {
        let center = NotificationCenter.default
        let show = center.addObserver(forName: UIResponder.keyboardWillShowNotification,
                                      object: nil,
                                      queue: .main) { [weak self] _ in
            self?.setKeyboardCompactLayout(true)
        }
        let hide = center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                      object: nil,
                                      queue: .main) { [weak self] _ in
            self?.setKeyboardCompactLayout(false)
        }
        keyboardObservers = [show, hide]
    }

    private func setKeyboardCompactLayout(_ compact: Bool) {
        if compact {
            retroKeypadView.isHidden = true
            retroClickWheelView.isHidden = true
            if let keypadTopConstraint {
                NSLayoutConstraint.deactivate([keypadTopConstraint])
            }
            if let clickWheelTopConstraint {
                NSLayoutConstraint.deactivate([clickWheelTopConstraint])
            }
            if let clickWheelBottomConstraint {
                NSLayoutConstraint.deactivate([clickWheelBottomConstraint])
            }
            if let screenBottomConstraint {
                NSLayoutConstraint.activate([screenBottomConstraint])
            }
        } else {
            retroKeypadView.isHidden = false
            retroClickWheelView.isHidden = false
            if let screenBottomConstraint {
                NSLayoutConstraint.deactivate([screenBottomConstraint])
            }
            if let keypadTopConstraint {
                NSLayoutConstraint.activate([keypadTopConstraint])
            }
            if let clickWheelTopConstraint {
                NSLayoutConstraint.activate([clickWheelTopConstraint])
            }
            if let clickWheelBottomConstraint {
                NSLayoutConstraint.activate([clickWheelBottomConstraint])
            }
        }
        view.layoutIfNeeded()
    }

    private func configureRetroShell() {
        retroShellView.translatesAutoresizingMaskIntoConstraints = false
        retroScreenView.translatesAutoresizingMaskIntoConstraints = false
        retroKeypadView.translatesAutoresizingMaskIntoConstraints = false
        retroSpeakerView.translatesAutoresizingMaskIntoConstraints = false
        retroBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        retroKeypadGrid.translatesAutoresizingMaskIntoConstraints = false
        retroKeypadRowTop.translatesAutoresizingMaskIntoConstraints = false
        retroKeypadRowBottom.translatesAutoresizingMaskIntoConstraints = false
        retroAntennaView.translatesAutoresizingMaskIntoConstraints = false
        retroAntennaTipView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelCenterView.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelVerticalDivider.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelHorizontalDivider.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelFolderButton.translatesAutoresizingMaskIntoConstraints = false
        retroClickWheelWordButton.translatesAutoresizingMaskIntoConstraints = false

        retroKeypadGrid.axis = .vertical
        retroKeypadGrid.spacing = AppSpacing.s(10)
        retroKeypadGrid.distribution = .fillEqually

        retroKeypadRowTop.axis = .horizontal
        retroKeypadRowTop.spacing = AppSpacing.s(12)
        retroKeypadRowTop.distribution = .fill

        retroKeypadRowBottom.axis = .horizontal
        retroKeypadRowBottom.spacing = AppSpacing.s(12)
        retroKeypadRowBottom.distribution = .fillEqually

        retroKeyButtons = [retroFolderButton, retroWordButton, retroSortButton, retroAddButton]
        let configButtons: [(UIButton, String)] = [
            (retroFolderButton, "追加"),
            (retroWordButton, "共有"),
            (retroSortButton, "並び替え"),
            (retroAddButton, "学習")
        ]
        configButtons.forEach { button, title in
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
            button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        }
        retroFolderButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        retroWordButton.setContentHuggingPriority(.required, for: .horizontal)

        retroKeypadRowTop.addArrangedSubview(retroAddButton)
        retroKeypadRowTop.addArrangedSubview(retroWordButton)
        retroKeypadRowBottom.addArrangedSubview(retroSortButton)
        retroKeypadRowBottom.addArrangedSubview(retroFolderButton)
        retroKeypadGrid.addArrangedSubview(retroKeypadRowTop)
        retroKeypadGrid.addArrangedSubview(retroKeypadRowBottom)

        retroBadgeLabel.text = "Y2K"
        retroBadgeLabel.textAlignment = .center

        [retroClickWheelFolderButton, retroClickWheelWordButton].forEach { button in
            button.layer.cornerRadius = 10
            button.layer.borderWidth = 1
            button.titleLabel?.font = AppFont.jp(size: 11, weight: .bold)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        }
        retroClickWheelFolderButton.setTitle("戻る", for: .normal)
        retroClickWheelWordButton.setTitle("単語", for: .normal)

        retroKeypadView.addSubview(retroKeypadGrid)

        retroShellView.addSubview(retroSpeakerView)
        retroShellView.addSubview(retroAntennaView)
        retroShellView.addSubview(retroAntennaTipView)
        retroShellView.addSubview(retroClickWheelView)
        retroShellView.addSubview(retroBadgeLabel)
        retroShellView.addSubview(retroScreenView)
        retroShellView.addSubview(retroKeypadView)

        retroClickWheelView.addSubview(retroClickWheelVerticalDivider)
        retroClickWheelView.addSubview(retroClickWheelHorizontalDivider)
        retroClickWheelView.addSubview(retroClickWheelCenterView)
        retroClickWheelView.addSubview(retroClickWheelFolderButton)
        retroClickWheelView.addSubview(retroClickWheelWordButton)

        view.addSubview(retroShellView)

        retroShellBottomConstraint = {
            if #available(iOS 15.0, *) {
                return retroShellView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -AppSpacing.s(16))
            }
            return retroShellView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -AppSpacing.s(16))
        }()

        keypadTopConstraint = retroKeypadView.topAnchor.constraint(equalTo: retroScreenView.bottomAnchor, constant: AppSpacing.s(12))
        clickWheelTopConstraint = retroClickWheelView.topAnchor.constraint(equalTo: retroKeypadView.bottomAnchor, constant: AppSpacing.s(16))
        clickWheelBottomConstraint = retroClickWheelView.bottomAnchor.constraint(equalTo: retroShellView.bottomAnchor, constant: -AppSpacing.s(16))
        screenBottomConstraint = retroScreenView.bottomAnchor.constraint(equalTo: retroShellView.bottomAnchor, constant: -AppSpacing.s(16))

        NSLayoutConstraint.activate([
            retroShellView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(16)),
            retroShellView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(28)),
            retroShellView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(28)),
            retroShellBottomConstraint!,

            retroSpeakerView.topAnchor.constraint(equalTo: retroShellView.topAnchor, constant: AppSpacing.s(12)),
            retroSpeakerView.centerXAnchor.constraint(equalTo: retroShellView.centerXAnchor),
            retroSpeakerView.widthAnchor.constraint(equalToConstant: 72),
            retroSpeakerView.heightAnchor.constraint(equalToConstant: 6),

            retroAntennaView.leadingAnchor.constraint(equalTo: retroShellView.leadingAnchor, constant: AppSpacing.s(44)),
            retroAntennaView.topAnchor.constraint(equalTo: retroShellView.topAnchor, constant: -AppSpacing.s(60)),
            retroAntennaView.widthAnchor.constraint(equalToConstant: 20),
            retroAntennaView.heightAnchor.constraint(equalToConstant: 85),

            retroAntennaTipView.centerXAnchor.constraint(equalTo: retroAntennaView.centerXAnchor),
            retroAntennaTipView.bottomAnchor.constraint(equalTo: retroAntennaView.topAnchor, constant: AppSpacing.s(4)),
            retroAntennaTipView.widthAnchor.constraint(equalToConstant: 24),
            retroAntennaTipView.heightAnchor.constraint(equalToConstant: 24),

            retroBadgeLabel.centerYAnchor.constraint(equalTo: retroSpeakerView.centerYAnchor),
            retroBadgeLabel.trailingAnchor.constraint(equalTo: retroShellView.trailingAnchor, constant: -AppSpacing.s(16)),
            retroBadgeLabel.widthAnchor.constraint(equalToConstant: 44),
            retroBadgeLabel.heightAnchor.constraint(equalToConstant: 20),

            retroScreenView.topAnchor.constraint(equalTo: retroSpeakerView.bottomAnchor, constant: AppSpacing.s(4)),
            retroScreenView.leadingAnchor.constraint(equalTo: retroShellView.leadingAnchor, constant: AppSpacing.s(12)),
            retroScreenView.trailingAnchor.constraint(equalTo: retroShellView.trailingAnchor, constant: -AppSpacing.s(12)),

            keypadTopConstraint!,
            retroKeypadView.leadingAnchor.constraint(equalTo: retroShellView.leadingAnchor, constant: AppSpacing.s(16)),
            retroKeypadView.trailingAnchor.constraint(equalTo: retroShellView.trailingAnchor, constant: -AppSpacing.s(16)),

            clickWheelTopConstraint!,
            retroClickWheelView.centerXAnchor.constraint(equalTo: retroShellView.centerXAnchor),
            clickWheelBottomConstraint!,

            retroClickWheelCenterView.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            retroClickWheelCenterView.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelCenterView.widthAnchor.constraint(equalToConstant: 48),
            retroClickWheelCenterView.heightAnchor.constraint(equalToConstant: 48),

            retroClickWheelVerticalDivider.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            retroClickWheelVerticalDivider.topAnchor.constraint(equalTo: retroClickWheelView.topAnchor, constant: AppSpacing.s(18)),
            retroClickWheelVerticalDivider.bottomAnchor.constraint(equalTo: retroClickWheelView.bottomAnchor, constant: -AppSpacing.s(18)),
            retroClickWheelVerticalDivider.widthAnchor.constraint(equalToConstant: 2),

            retroClickWheelHorizontalDivider.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelHorizontalDivider.leadingAnchor.constraint(equalTo: retroClickWheelView.leadingAnchor, constant: AppSpacing.s(18)),
            retroClickWheelHorizontalDivider.trailingAnchor.constraint(equalTo: retroClickWheelView.trailingAnchor, constant: -AppSpacing.s(18)),
            retroClickWheelHorizontalDivider.heightAnchor.constraint(equalToConstant: 2),

            retroClickWheelFolderButton.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelFolderButton.centerXAnchor.constraint(equalTo: retroClickWheelView.leadingAnchor, constant: AppSpacing.s(35)),
            retroClickWheelFolderButton.widthAnchor.constraint(equalToConstant: 50),
            retroClickWheelFolderButton.heightAnchor.constraint(equalToConstant: 32),

            retroClickWheelWordButton.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor),
            retroClickWheelWordButton.centerXAnchor.constraint(equalTo: retroClickWheelView.trailingAnchor, constant: -AppSpacing.s(35)),
            retroClickWheelWordButton.widthAnchor.constraint(equalToConstant: 50),
            retroClickWheelWordButton.heightAnchor.constraint(equalToConstant: 32),

            retroKeypadGrid.topAnchor.constraint(equalTo: retroKeypadView.topAnchor, constant: AppSpacing.s(6)),
            retroKeypadGrid.leadingAnchor.constraint(equalTo: retroKeypadView.leadingAnchor, constant: AppSpacing.s(12)),
            retroKeypadGrid.trailingAnchor.constraint(equalTo: retroKeypadView.trailingAnchor, constant: -AppSpacing.s(12)),
            retroKeypadGrid.bottomAnchor.constraint(equalTo: retroKeypadView.bottomAnchor, constant: -AppSpacing.s(6)),

        ])

        let screenMinHeight = retroScreenView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160)
        screenMinHeight.priority = .defaultLow
        screenMinHeight.isActive = true

        let keypadPreferredHeight = retroKeypadView.heightAnchor.constraint(equalToConstant: 140)
        keypadPreferredHeight.priority = .defaultHigh
        keypadPreferredHeight.isActive = true
        let keypadMaxHeight = retroKeypadView.heightAnchor.constraint(lessThanOrEqualToConstant: 150)
        keypadMaxHeight.priority = .required
        keypadMaxHeight.isActive = true
        let keypadMinHeight = retroKeypadView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96)
        keypadMinHeight.priority = .defaultLow
        keypadMinHeight.isActive = true

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

        let folderWidth = retroFolderButton.widthAnchor.constraint(greaterThanOrEqualTo: retroWordButton.widthAnchor, multiplier: 1.2)
        folderWidth.priority = .defaultHigh
        folderWidth.isActive = true
        let equalSortWidth = retroSortButton.widthAnchor.constraint(equalTo: retroFolderButton.widthAnchor)
        let equalAddWidth = retroAddButton.widthAnchor.constraint(equalTo: retroFolderButton.widthAnchor)
        equalSortWidth.isActive = true
        equalAddWidth.isActive = true

        retroFolderButton.addTarget(self, action: #selector(openAddSet), for: .touchUpInside)
        retroWordButton.addTarget(self, action: #selector(openShareMenu), for: .touchUpInside)
        retroSortButton.addTarget(self, action: #selector(openSortMenu), for: .touchUpInside)
        retroAddButton.addTarget(self, action: #selector(openWhichView), for: .touchUpInside)
        retroClickWheelFolderButton.addTarget(self, action: #selector(openFolderView), for: .touchUpInside)
        retroClickWheelWordButton.addTarget(self, action: #selector(openWordMenuFromClickWheel), for: .touchUpInside)
    }

    private func configureThemeHeader() {
        themeHeader.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: themeHeaderHeight)
        themeHeader.translatesAutoresizingMaskIntoConstraints = false

        themeTitleLabel.text = "テーマ"
        themeTitleLabel.textAlignment = .left

        themeStack.axis = .horizontal
        themeStack.spacing = AppSpacing.s(12)
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
            themeTitleLabel.topAnchor.constraint(equalTo: themeHeader.topAnchor, constant: AppSpacing.s(12)),
            themeTitleLabel.leadingAnchor.constraint(equalTo: themeHeader.leadingAnchor, constant: AppSpacing.s(20)),
            themeTitleLabel.trailingAnchor.constraint(equalTo: themeHeader.trailingAnchor, constant: -AppSpacing.s(20)),

            themeStack.topAnchor.constraint(equalTo: themeTitleLabel.bottomAnchor, constant: AppSpacing.s(12)),
            themeStack.leadingAnchor.constraint(equalTo: themeHeader.leadingAnchor, constant: AppSpacing.s(20)),
            themeStack.trailingAnchor.constraint(equalTo: themeHeader.trailingAnchor, constant: -AppSpacing.s(20)),
            themeStack.heightAnchor.constraint(equalToConstant: 36),
        ])

        headerContainer.addSubview(themeHeader)
        tableView.tableHeaderView = headerContainer
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
        cell.accessibilityIdentifier = set.id
        let count = wordCount(for: set)
        cell.textLabel?.text = set.name
        cell.detailTextLabel?.text = "単語 \(count) 個"
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.font = AppFont.jp(size: 18, weight: .bold)
        cell.detailTextLabel?.font = AppFont.jp(size: 14)
        let palette = ThemeManager.palette()
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = palette.text
        cell.detailTextLabel?.textColor = palette.mutedText
        applyRetroCellStyle(cell)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        handleSelection(at: indexPath)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard indexPath.row < displayedSetCache.count else { return nil }
        let setID = displayedSetCache[indexPath.row].id
        let move = UIContextualAction(style: .normal, title: "フォルダー") { [weak self] _, _, completion in
            self?.showMoveSetSheet(for: indexPath)
            completion(true)
        }
        move.backgroundColor = .systemBlue
        let delete = UIContextualAction(style: .destructive, title: "削除") { [weak self] _, _, completion in
            self?.deleteSet(id: setID)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, move])
    }

    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        tapGesture.isEnabled = false
    }

    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        tapGesture.isEnabled = true
    }

    @objc private func openAddSet() {
        let controller = SetCreateViewController(folderID: folderID)
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openWordList() {
        openWordListForEditing(false, hideActions: true, showHideButton: true)
    }

    @objc private func openShareMenu() {
        let sets = displayedSets()
        guard !sets.isEmpty else {
            showAlert(title: "共有できるセットがありません", message: "先にセットを作成してください。")
            return
        }
        var actions = sets.map { set in
            UnifiedModalAction(title: set.name) { [weak self] in
                self?.sendSetToGroup(set)
            }
        }
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "共有するセット",
                            message: "SharePlay中の参加者に送信されます。",
                            actions: actions)
    }

    private func sendSetToGroup(_ set: SavedSet) {
        let data = buildShareData(for: set)
        guard !data.isEmpty else {
            showAlert(title: "共有エラー", message: "データの作成に失敗しました。")
            return
        }
        shareManager.send(data)
    }

    private func buildShareData(for set: SavedSet) -> Data {
        let allWords = loadSavedWords()
        let wordMap = Dictionary(uniqueKeysWithValues: allWords.map { ($0.id, $0) })
        let words = set.wordIDs.compactMap { wordMap[$0] }
        let payload = SharedWordSet(set: set, words: words)
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }

    private func showAlert(title: String, message: String) {
        let presentBlock = { [weak self] in
            self?.presentUnifiedModal(title: title,
                                      message: message,
                                      actions: [UnifiedModalAction(title: "OK")])
        }
        if let presented = presentedViewController as? UnifiedModalViewController {
            presented.dismiss(animated: false) {
                presentBlock()
            }
            return
        }
        guard presentedViewController == nil else { return }
        presentBlock()
    }

    private struct SharedWordSet: Codable {
        let set: SavedSet
        let words: [SavedWord]
    }

    private func setupShareManager() {
        shareManager.onReceiveData = { [weak self] data in
            DispatchQueue.main.async {
                self?.handleReceivedShare(data: data)
            }
        }
        shareManager.onStatus = { [weak self] text in
            DispatchQueue.main.async {
                self?.retroBadgeLabel.text = "共有"
                self?.retroBadgeLabel.accessibilityLabel = text
            }
        }
        shareManager.onError = { [weak self] text in
            DispatchQueue.main.async {
                self?.showAlert(title: "共有エラー", message: text)
            }
        }
    }

    private func handleReceivedShare(data: Data) {
        guard let payload = try? JSONDecoder().decode(SharedWordSet.self, from: data) else {
            showAlert(title: "受信エラー", message: "データの読み込みに失敗しました。")
            return
        }
        importSharedSet(payload)
        reloadData()
        showAlert(title: "受信完了", message: "\(payload.set.name) を追加しました。")
    }

    private func importSharedSet(_ payload: SharedWordSet) {
        var savedWords = loadSavedWords()
        var existingByID: [String: SavedWord] = [:]
        savedWords.forEach { existingByID[$0.id] = $0 }

        var idMap: [String: String] = [:]
        for word in payload.words {
            if let existing = existingByID[word.id] {
                if existing.english == word.english && existing.japanese == word.japanese {
                    idMap[word.id] = word.id
                } else {
                    let newWord = SavedWord(english: word.english,
                                            japanese: word.japanese,
                                            illustrationScenario: word.illustrationScenario,
                                            illustrationImageFileName: word.illustrationImageFileName,
                                            isFavorite: word.isFavorite,
                                            importanceLevel: word.importanceLevel)
                    savedWords.append(newWord)
                    idMap[word.id] = newWord.id
                }
            } else {
                savedWords.append(word)
                idMap[word.id] = word.id
            }
        }
        saveSavedWords(savedWords)

        var sets = SetStore.loadSets()
        let newName = uniqueSetName(payload.set.name, existing: sets.map { $0.name })
        let newIDs = payload.set.wordIDs.compactMap { idMap[$0] }
        let newSet = SavedSet(name: newName,
                              wordIDs: newIDs,
                              folderID: payload.set.folderID)
        sets.append(newSet)
        SetStore.saveSets(sets)
    }

    private func uniqueSetName(_ base: String, existing: [String]) -> String {
        if !existing.contains(base) { return base }
        var index = 2
        while existing.contains("\(base) (共有\(index))") {
            index += 1
        }
        return "\(base) (共有\(index))"
    }

    private func openWordListForEditing(_ editing: Bool,
                                        hideActions: Bool,
                                        showHideButton: Bool = false) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let listVC = storyboard.instantiateViewController(withIdentifier: "ListTableViewController")
                as? ListTableViewController else {
            return
        }
        listVC.startEditing = editing
        listVC.hideTestAndAdd = hideActions
        listVC.showHideButton = showHideButton
        navigationController?.pushViewController(listVC, animated: true)
    }

    @objc private func openWordMenuFromClickWheel() {
        showWordMenuModal()
    }

    private func openAddWord() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let addVC = storyboard.instantiateViewController(withIdentifier: "AddViewController")
        navigationController?.pushViewController(addVC, animated: true)
    }

    @objc private func openWhichView() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let whichVC = storyboard.instantiateViewController(withIdentifier: "WhichViewController")
        navigationController?.pushViewController(whichVC, animated: true)
    }

    @objc private func openFolderView() {
        guard let navigationController else { return }
        if let target = navigationController.viewControllers.first(where: { $0 is FolderViewController }) {
            navigationController.popToViewController(target, animated: true)
            return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let controller = storyboard.instantiateViewController(withIdentifier: "FolderViewController") as? FolderViewController {
            navigationController.pushViewController(controller, animated: true)
        }
    }

    @objc private func backToFolders() {
        openFolderView()
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
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: -20, left: 0, bottom: 20, right: 0)
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorColor = palette.border
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
        retroClickWheelFolderButton.backgroundColor = UIColor.systemGray6
        retroClickWheelFolderButton.layer.borderColor = UIColor.systemGray3.cgColor
        retroClickWheelFolderButton.setTitleColor(palette.text, for: .normal)
        retroClickWheelWordButton.backgroundColor = UIColor.systemGray6
        retroClickWheelWordButton.layer.borderColor = UIColor.systemGray3.cgColor
        retroClickWheelWordButton.setTitleColor(palette.text, for: .normal)

        retroKeypadView.backgroundColor = UIColor(white: 0.18, alpha: 1.0)
        retroKeypadView.layer.cornerRadius = 22
        retroKeypadView.layer.borderWidth = 2
        retroKeypadView.layer.borderColor = palette.border.cgColor

        retroKeyButtons.forEach { key in
            key.backgroundColor = UIColor.systemGray6
            key.layer.borderColor = UIColor.systemGray3.cgColor
            key.setTitleColor(palette.text, for: .normal)
            key.layer.shadowColor = UIColor.systemGray3.cgColor
            key.layer.shadowOpacity = 0.2
            key.layer.shadowOffset = CGSize(width: 0, height: 2)
            key.layer.shadowRadius = 3
        }

        retroBadgeLabel.font = AppFont.title(size: 9)
        retroBadgeLabel.textColor = palette.text
        retroBadgeLabel.backgroundColor = palette.surfaceAlt
        retroBadgeLabel.layer.cornerRadius = 8
        retroBadgeLabel.layer.borderWidth = 1
        retroBadgeLabel.layer.borderColor = palette.border.cgColor
        retroBadgeLabel.clipsToBounds = true

        retroAddButton.backgroundColor = UIColor.systemGray6
        retroAddButton.setTitleColor(palette.text, for: .normal)
        retroAddButton.layer.borderColor = UIColor.systemGray3.cgColor
        retroAddButton.layer.shadowColor = UIColor.systemGray3.cgColor
        retroAddButton.layer.shadowOpacity = 0.25
        retroAddButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        retroAddButton.layer.shadowRadius = 3

        themeHeader.backgroundColor = palette.surface
        themeHeader.layer.cornerRadius = 16
        themeHeader.layer.borderWidth = 2
        themeHeader.layer.borderColor = palette.border.cgColor
        themeHeader.clipsToBounds = true
        themeTitleLabel.font = AppFont.jp(size: 16, weight: .bold)
        themeTitleLabel.textColor = palette.text

        for (index, button) in themeButtons.enumerated() {
            let theme = AppTheme.allCases[index]
            button.backgroundColor = ThemeManager.palette(for: theme).accent
        }
        updateThemeSelection()
        updateWordMenuModalTheme()
        tableView.reloadData()
    }

    private func showWordMenuModal() {
        guard wordMenuOverlay == nil else { return }
        let overlay = UIControl()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.addTarget(self, action: #selector(dismissWordMenuModal), for: .touchUpInside)
        overlay.accessibilityViewIsModal = true

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "単語"
        titleLabel.textAlignment = .center

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = AppSpacing.s(8)

        let listButton = makeWordMenuButton(title: "単語一覧", action: #selector(handleWordMenuList))
        let addButton = makeWordMenuButton(title: "単語追加", action: #selector(handleWordMenuAdd))
        let editButton = makeWordMenuButton(title: "編集", action: #selector(handleWordMenuEdit))
        let cancelButton = makeWordMenuButton(title: "キャンセル", action: #selector(dismissWordMenuModal))

        [listButton, addButton, editButton, cancelButton].forEach { button in
            stack.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }

        container.addSubview(titleLabel)
        container.addSubview(stack)
        overlay.addSubview(container)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.centerXAnchor.constraint(equalTo: retroClickWheelView.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: retroClickWheelView.centerYAnchor, constant: -110),
            container.widthAnchor.constraint(equalToConstant: 240),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(24)),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(24)),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: AppSpacing.s(16)),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(12)),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: AppSpacing.s(16)),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -AppSpacing.s(16)),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -AppSpacing.s(16)),
        ])

        wordMenuOverlay = overlay
        wordMenuContainer = container
        wordMenuTitleLabel = titleLabel
        wordMenuButtons = [listButton, addButton, editButton, cancelButton]
        updateWordMenuModalTheme()

        overlay.alpha = 0
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            overlay.alpha = 1
            container.alpha = 1
            container.transform = .identity
        }
    }

    @objc private func dismissWordMenuModal() {
        guard let overlay = wordMenuOverlay, let container = wordMenuContainer else { return }
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            overlay.alpha = 0
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { [weak self] _ in
            overlay.removeFromSuperview()
            self?.wordMenuOverlay = nil
            self?.wordMenuContainer = nil
            self?.wordMenuTitleLabel = nil
            self?.wordMenuButtons = []
        }
    }

    @objc private func handleWordMenuList() {
        dismissWordMenuModal()
        openWordListForEditing(false, hideActions: true)
    }

    @objc private func handleWordMenuAdd() {
        dismissWordMenuModal()
        openAddWord()
    }

    @objc private func handleWordMenuEdit() {
        dismissWordMenuModal()
        openWordListForEditing(true, hideActions: true)
    }

    private func makeWordMenuButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.titleLabel?.font = AppFont.jp(size: 14, weight: .bold)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        button.layer.borderWidth = 2
        button.layer.cornerRadius = 0
        button.layer.masksToBounds = true
        return button
    }

    private func updateWordMenuModalTheme() {
        guard let overlay = wordMenuOverlay,
              let container = wordMenuContainer,
              let titleLabel = wordMenuTitleLabel else { return }
        let palette = ThemeManager.palette()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        container.backgroundColor = palette.surface
        container.layer.borderWidth = 2
        container.layer.borderColor = palette.border.cgColor
        container.layer.cornerRadius = 0
        titleLabel.font = AppFont.jp(size: 16, weight: .bold)
        titleLabel.textColor = palette.text
        wordMenuButtons.forEach { button in
            button.backgroundColor = palette.surfaceAlt
            button.layer.borderColor = palette.border.cgColor
            button.setTitleColor(palette.text, for: .normal)
        }
    }

    private func updateHeaderLayout() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        let totalHeight = themeHeaderHeight
        header.frame = CGRect(x: 0, y: 0, width: width, height: totalHeight)
        themeHeader.frame = CGRect(x: 0, y: 0, width: width, height: themeHeaderHeight)
        tableView.tableHeaderView = header

        let keyHeight = retroKeypadRowTop.bounds.height
        if keyHeight > 0 {
            retroKeyButtons.forEach { $0.layer.cornerRadius = keyHeight / 2 }
        }
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

    private func applyRetroCellStyle(_ cell: UITableViewCell) {
        let containerTag = 9911
        let container: UIView
        if let existing = cell.contentView.viewWithTag(containerTag) {
            container = existing
        } else {
            container = UIView()
            container.tag = containerTag
            container.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.insertSubview(container, at: 0)
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: AppSpacing.s(12)),
                container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -AppSpacing.s(12)),
                container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: AppSpacing.s(6)),
                container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -AppSpacing.s(6)),
            ])
        }

        let palette = ThemeManager.palette()
        container.backgroundColor = palette.surface
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 1.5
        container.layer.borderColor = palette.border.cgColor
        container.layer.shadowColor = palette.border.cgColor
        container.layer.shadowOpacity = 0.12
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4
        container.layer.masksToBounds = false

        cell.selectionStyle = .none
        cell.contentView.clipsToBounds = false
        cell.clipsToBounds = false
        cell.contentView.sendSubviewToBack(container)
    }

    @objc private func openSortMenu() {
        let actions: [UnifiedModalAction] = [
            UnifiedModalAction(title: "作成順") { [weak self] in
                self?.sortOption = .created
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "名前 A→Z") { [weak self] in
                self?.sortOption = .nameAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "名前 Z→A") { [weak self] in
                self?.sortOption = .nameDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "単語数 少ない→多い") { [weak self] in
                self?.sortOption = .countAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "単語数 多い→少ない") { [weak self] in
                self?.sortOption = .countDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "キャンセル", style: .cancel)
        ]
        presentUnifiedModal(title: "並び替え", message: nil, actions: actions)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
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
        let nameField = UITextField()
        nameField.borderStyle = .roundedRect
        nameField.text = set.name
        nameField.placeholder = "セット名"
        presentUnifiedModal(
            title: "名前変更",
            message: nil,
            contentView: nameField,
            actions: [
                UnifiedModalAction(title: "キャンセル", style: .cancel),
                UnifiedModalAction(title: "保存") { [weak self] in
                    guard let self else { return }
                    let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !name.isEmpty else { return }
                    if let index = self.sets.firstIndex(where: { $0.id == set.id }) {
                        self.sets[index].name = name
                        SetStore.saveSets(self.sets)
                        self.applyFilterAndReload()
                    }
                }
            ]
        )
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

    private func deleteSet(id: String) {
        var allSets = SetStore.loadSets()
        if let index = allSets.firstIndex(where: { $0.id == id }) {
            allSets.remove(at: index)
            SetStore.saveSets(allSets)
        }
        reloadData()
    }

    private func showMoveSetSheet(for indexPath: IndexPath) {
        let set = displayedSets()[indexPath.row]
        let folders = FolderStore.loadFolders()
        var actions: [UnifiedModalAction] = [
            UnifiedModalAction(title: "未分類") { [weak self] in
                self?.moveSet(setID: set.id, to: nil)
            }
        ]
        actions.append(contentsOf: folders.map { folder in
            UnifiedModalAction(title: folder.name) { [weak self] in
                self?.moveSet(setID: set.id, to: folder.id)
            }
        })
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "フォルダー移動", message: nil, actions: actions)
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
        buttonStack.spacing = AppSpacing.s(16)
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
            buttonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(12)),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(16)),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(16)),
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
            tableView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: AppSpacing.s(12)),
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

        tableView.tableHeaderView = headerContainer
        definesPresentationContext = true
    }

    private func updateHeaderLayout() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        let searchHeight = searchController.searchBar.bounds.height
        let headerHeight = searchHeight
        header.frame = CGRect(x: 0, y: 0, width: width, height: headerHeight)
        searchController.searchBar.frame = CGRect(x: 0, y: 0, width: width, height: searchHeight)
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
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(20)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(20)),
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
        LastStudyStore.save(setID: setID, setName: setName)
        let controller = FlipViewController()
        controller.presetWords = words
        controller.title = "\(setName) フリップ"
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func openTest() {
        LastStudyStore.save(setID: setID, setName: setName)
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
        let nameField = UITextField()
        nameField.borderStyle = .roundedRect
        nameField.text = setName
        nameField.placeholder = "セット名"
        presentUnifiedModal(
            title: "名前変更",
            message: nil,
            contentView: nameField,
            actions: [
                UnifiedModalAction(title: "キャンセル", style: .cancel),
                UnifiedModalAction(title: "保存") { [weak self] in
                    guard let self else { return }
                    let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !name.isEmpty else { return }
                    var sets = SetStore.loadSets()
                    if let index = sets.firstIndex(where: { $0.id == self.setID }) {
                        sets[index].name = name
                        SetStore.saveSets(sets)
                        self.setName = name
                        self.title = name
                    }
                }
            ]
        )
    }

    @objc private func openSortMenu() {
        let actions: [UnifiedModalAction] = [
            UnifiedModalAction(title: "セット順") { [weak self] in
                self?.sortOption = .setOrder
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "英語 A→Z") { [weak self] in
                self?.sortOption = .englishAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "英語 Z→A") { [weak self] in
                self?.sortOption = .englishDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "日本語 あ→ん") { [weak self] in
                self?.sortOption = .japaneseAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "日本語 ん→あ") { [weak self] in
                self?.sortOption = .japaneseDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "キャンセル", style: .cancel)
        ]
        presentUnifiedModal(title: "並び替え", message: nil, actions: actions)
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

        presentUnifiedModal(
            title: "隠す項目",
            message: nil,
            actions: [
                UnifiedModalAction(title: "英語を隠す") { [weak self] in
                    self?.hiddenMode = .english
                    self?.revealedWordIDs.removeAll()
                    self?.updateHiddenButtonTitle()
                    self?.tableView.reloadData()
                },
                UnifiedModalAction(title: "日本語を隠す") { [weak self] in
                    self?.hiddenMode = .japanese
                    self?.revealedWordIDs.removeAll()
                    self?.updateHiddenButtonTitle()
                    self?.tableView.reloadData()
                },
                UnifiedModalAction(title: "キャンセル", style: .cancel)
            ]
        )
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
            presentUnifiedModal(
                title: "移動先がありません",
                message: "他のセットを作成してください。",
                actions: [UnifiedModalAction(title: "OK")]
            )
            return
        }
        var actions = targets.map { target in
            UnifiedModalAction(title: target.name) { [weak self] in
                self?.moveWord(wordID: word.id, to: target.id)
            }
        }
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "移動先を選択", message: nil, actions: actions)
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
        var actions: [UnifiedModalAction] = (1...5).map { level in
            UnifiedModalAction(title: "Lv\(level)") { [weak self] in
                self?.updateWord(id: word.id, importanceLevel: level)
                if let indexPath = self?.indexPathForWord(id: word.id),
                   let cell = self?.tableView.cellForRow(at: indexPath) as? ListTableViewCell {
                    cell.updateImportance(level: level)
                }
            }
        }
        actions.append(UnifiedModalAction(title: "キャンセル", style: .cancel))
        presentUnifiedModal(title: "重要度", message: nil, actions: actions)
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
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(12)),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(16)),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(16)),
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
            tableView.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: AppSpacing.s(12)),
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
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(20)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(20)),
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
        presentUnifiedModal(title: title,
                            message: message,
                            actions: [UnifiedModalAction(title: "OK")])
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
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: AppSpacing.s(20)),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -AppSpacing.s(20)),
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
        let actions: [UnifiedModalAction] = [
            UnifiedModalAction(title: "作成順") { [weak self] in
                self?.sortOption = .created
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "英語 A→Z") { [weak self] in
                self?.sortOption = .englishAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "英語 Z→A") { [weak self] in
                self?.sortOption = .englishDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "日本語 あ→ん") { [weak self] in
                self?.sortOption = .japaneseAsc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "日本語 ん→あ") { [weak self] in
                self?.sortOption = .japaneseDesc
                self?.applyFilterAndReload()
            },
            UnifiedModalAction(title: "キャンセル", style: .cancel)
        ]
        presentUnifiedModal(title: "並び替え", message: nil, actions: actions)
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
            presentUnifiedModal(
                title: "選択エラー",
                message: "単語を1つ以上選択してください。",
                actions: [UnifiedModalAction(title: "OK")]
            )
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
