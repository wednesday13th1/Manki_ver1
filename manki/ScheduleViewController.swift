//
//  ScheduleViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class ScheduleViewController: UIViewController {

    private let scheduleFileName = "schedule.json"
    private var items: [ScheduleItem] = []

    private let countdownLabel = UILabel()
    private let monthLabel = UILabel()
    private let prevMonthButton = UIButton(type: .system)
    private let nextMonthButton = UIButton(type: .system)
    private let weekStack = UIStackView()
    private lazy var calendarCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    private let addButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let calendar = Calendar.current
    private var currentMonthDate = Date()
    private let colorOptions: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple]
    private var selectedColorIndex: Int = 0
    private var themeObserver: NSObjectProtocol?
    private let tabTitle = "スケジュール"
    private let showCountdown = true

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = tabTitle
        tabBarController?.title = tabTitle
        tabBarController?.navigationItem.title = tabTitle
        navigationController?.navigationBar.topItem?.title = tabTitle
        tabBarItem.title = tabTitle
        currentMonthDate = startOfMonth(for: Date())

        configureUI()
        updateCountdown()
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
        reloadItems()
        if showCountdown {
            countdownLabel.isHidden = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCountdown()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func configureUI() {
        if showCountdown {
            countdownLabel.font = AppFont.jp(size: 18, weight: .bold)
            countdownLabel.numberOfLines = 0
            countdownLabel.textAlignment = .center
            countdownLabel.text = "次の小テストを読み込み中..."
            countdownLabel.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(countdownLabel)
        }

        prevMonthButton.setTitle("＜", for: .normal)
        prevMonthButton.addTarget(self, action: #selector(showPrevMonth), for: .touchUpInside)
        prevMonthButton.translatesAutoresizingMaskIntoConstraints = false

        nextMonthButton.setTitle("＞", for: .normal)
        nextMonthButton.addTarget(self, action: #selector(showNextMonth), for: .touchUpInside)
        nextMonthButton.translatesAutoresizingMaskIntoConstraints = false

        monthLabel.font = AppFont.jp(size: 18, weight: .bold)
        monthLabel.textAlignment = .center
        monthLabel.translatesAutoresizingMaskIntoConstraints = false

        let monthHeader = UIStackView(arrangedSubviews: [prevMonthButton, monthLabel, nextMonthButton])
        monthHeader.axis = .horizontal
        monthHeader.alignment = .center
        monthHeader.distribution = .equalCentering
        monthHeader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(monthHeader)

        weekStack.axis = .horizontal
        weekStack.distribution = .fillEqually
        weekStack.translatesAutoresizingMaskIntoConstraints = false
        ["日", "月", "火", "水", "木", "金", "土"].forEach { title in
            let label = UILabel()
            label.text = title
            label.font = AppFont.jp(size: 12, weight: .bold)
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            weekStack.addArrangedSubview(label)
        }
        view.addSubview(weekStack)

        calendarCollectionView.translatesAutoresizingMaskIntoConstraints = false
        calendarCollectionView.backgroundColor = .clear
        calendarCollectionView.dataSource = self
        calendarCollectionView.delegate = self
        calendarCollectionView.register(CalendarDayCell.self,
                                         forCellWithReuseIdentifier: CalendarDayCell.reuseID)
        view.addSubview(calendarCollectionView)

        addButton.setTitle("予定を追加", for: .normal)
        addButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)
        addButton.addTarget(self, action: #selector(addSchedule), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        view.addSubview(tableView)

        emptyLabel.text = "スケジュールがありません。右上の＋で追加できます。"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        var constraints: [NSLayoutConstraint] = [
            monthHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            monthHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            monthHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            weekStack.topAnchor.constraint(equalTo: monthHeader.bottomAnchor, constant: 6),
            weekStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            weekStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            calendarCollectionView.topAnchor.constraint(equalTo: weekStack.bottomAnchor, constant: 4),
            calendarCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            calendarCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            calendarCollectionView.heightAnchor.constraint(equalToConstant: 300),

            addButton.topAnchor.constraint(equalTo: calendarCollectionView.bottomAnchor, constant: 8),
            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ]

        if showCountdown {
            constraints.append(contentsOf: [
                countdownLabel.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 10),
                countdownLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                countdownLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                tableView.topAnchor.constraint(equalTo: countdownLabel.bottomAnchor, constant: 12),
            ])
        } else {
            constraints.append(tableView.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 12))
        }

        constraints.append(contentsOf: [
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        NSLayoutConstraint.activate(constraints)

        updateMonthLabel()
    }

    private func reloadItems() {
        items = loadItems().sorted { $0.dateValue < $1.dateValue }
        emptyLabel.isHidden = !items.isEmpty
        tableView.reloadData()
        updateCountdown()
        calendarCollectionView.reloadData()
    }

    private func updateCountdown() {
        guard showCountdown else { return }
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let quizDates = items.filter { $0.isQuiz }.map { calendar.startOfDay(for: $0.dateValue) }
        let fallbackDates = items.map { calendar.startOfDay(for: $0.dateValue) }

        if let nextQuiz = quizDates.filter({ $0 >= startOfToday }).min() {
            let days = calendar.dateComponents([.day], from: startOfToday, to: nextQuiz).day ?? 0
            let dateText = formatDate(nextQuiz)
            if days == 0 {
                let text = "次の小テストは今日です！ (\(dateText))"
                countdownLabel.text = text
                navigationItem.title = text
                tabBarController?.title = text
                tabBarController?.navigationItem.title = text
                navigationController?.navigationBar.topItem?.title = text
            } else {
                let text = "次の小テストまであと \(days)日 (\(dateText))"
                countdownLabel.text = text
                navigationItem.title = text
                tabBarController?.title = text
                tabBarController?.navigationItem.title = text
                navigationController?.navigationBar.topItem?.title = text
            }
            return
        }

        if quizDates.isEmpty, let nextItem = fallbackDates.filter({ $0 >= startOfToday }).min() {
            let days = calendar.dateComponents([.day], from: startOfToday, to: nextItem).day ?? 0
            let dateText = formatDate(nextItem)
            let text = days == 0
                ? "次の予定は今日です！ (\(dateText))"
                : "次の予定まであと \(days)日 (\(dateText))"
            countdownLabel.text = text
            navigationItem.title = text
            tabBarController?.title = text
            tabBarController?.navigationItem.title = text
            navigationController?.navigationBar.topItem?.title = text
            return
        }

        if let latestQuiz = quizDates.max() {
            let dateText = formatDate(latestQuiz)
            let text = "次の小テストは未設定です。直近: \(dateText)"
            countdownLabel.text = text
            navigationItem.title = text
            tabBarController?.title = text
            tabBarController?.navigationItem.title = text
            navigationController?.navigationBar.topItem?.title = text
            return
        }

        let text = "次の小テストの日を追加してください。"
        countdownLabel.text = text
        navigationItem.title = text
        tabBarController?.title = text
        tabBarController?.navigationItem.title = text
        navigationController?.navigationBar.topItem?.title = text
    }

    private func startOfMonth(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func updateMonthLabel() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        monthLabel.text = formatter.string(from: currentMonthDate)
    }

    @objc private func showPrevMonth() {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: currentMonthDate) else { return }
        currentMonthDate = startOfMonth(for: prev)
        updateMonthLabel()
        calendarCollectionView.reloadData()
    }

    @objc private func showNextMonth() {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonthDate) else { return }
        currentMonthDate = startOfMonth(for: next)
        updateMonthLabel()
        calendarCollectionView.reloadData()
    }

    private func scheduleFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(scheduleFileName)
    }

    private func loadItems() -> [ScheduleItem] {
        let url = scheduleFileURL()
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        if let decoded = try? JSONDecoder().decode([ScheduleItem].self, from: data) {
            return decoded
        }
        return []
    }

    private func saveItems(_ items: [ScheduleItem]) {
        let url = scheduleFileURL()
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    @objc private func addSchedule() {
        let alert = UIAlertController(title: "スケジュール追加", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "タイトル (例: 小テスト)"
        }

        let contentVC = UIViewController()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let typeSegment = UISegmentedControl(items: ["予定", "小テスト"])
        typeSegment.selectedSegmentIndex = 0
        let colorStack = UIStackView()
        colorStack.axis = .horizontal
        colorStack.alignment = .center
        colorStack.distribution = .equalSpacing
        colorStack.spacing = 10
        colorStack.translatesAutoresizingMaskIntoConstraints = false

        var colorButtons: [UIButton] = []
        for (index, color) in colorOptions.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.backgroundColor = color
            button.layer.cornerRadius = 12
            button.layer.borderWidth = index == selectedColorIndex ? 2 : 0
            button.layer.borderColor = UIColor.label.cgColor
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 24),
                button.heightAnchor.constraint(equalToConstant: 24),
            ])
            button.addTarget(self, action: #selector(selectColor(_:)), for: .touchUpInside)
            colorButtons.append(button)
            colorStack.addArrangedSubview(button)
        }

        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }

        stack.addArrangedSubview(typeSegment)
        stack.addArrangedSubview(colorStack)
        stack.addArrangedSubview(datePicker)
        contentVC.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentVC.view.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: contentVC.view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentVC.view.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: contentVC.view.bottomAnchor, constant: -8),
        ])
        contentVC.preferredContentSize = CGSize(width: 250, height: 230)
        alert.setValue(contentVC, forKey: "contentViewController")

        let addAction = UIAlertAction(title: "追加", style: .default) { [weak self] _ in
            guard let self else { return }
            let title = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = (title?.isEmpty ?? true) ? "予定" : title!
            let isQuiz = typeSegment.selectedSegmentIndex == 1
            let newItem = ScheduleItem(id: UUID().uuidString,
                                       title: finalTitle,
                                       dateISO: self.isoString(from: datePicker.date),
                                       isQuiz: isQuiz,
                                       colorIndex: self.selectedColorIndex)
            var updated = self.loadItems()
            updated.append(newItem)
            self.saveItems(updated)
            self.reloadItems()
        }
        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(addAction)
        present(alert, animated: true)
    }

    private func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    @objc private func selectColor(_ sender: UIButton) {
        selectedColorIndex = sender.tag
        if let stack = sender.superview as? UIStackView {
            for case let button as UIButton in stack.arrangedSubviews {
                button.layer.borderWidth = button.tag == selectedColorIndex ? 2 : 0
            }
        }
    }
}

extension ScheduleViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scheduleCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "scheduleCell")
        let item = items[indexPath.row]
        cell.textLabel?.text = item.title
        let dateText = formatDate(item.dateValue)
        cell.detailTextLabel?.text = item.isQuiz ? "\(dateText)  小テスト" : dateText
        cell.selectionStyle = .none
        cell.textLabel?.font = AppFont.jp(size: 18, weight: .bold)
        cell.detailTextLabel?.font = AppFont.jp(size: 14)
        let palette = ThemeManager.palette()
        cell.backgroundColor = palette.surface
        cell.textLabel?.textColor = palette.text
        cell.detailTextLabel?.textColor = palette.mutedText
        return cell
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        var updated = loadItems()
        updated.removeAll { $0.id == items[indexPath.row].id }
        saveItems(updated)
        reloadItems()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentEdit(for: items[indexPath.row])
    }
}

extension ScheduleViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let firstOfMonth = startOfMonth(for: currentMonthDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let total = leading + daysInMonth
        let rows = Int(ceil(Double(total) / 7.0))
        return rows * 7
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDayCell.reuseID,
                                                      for: indexPath) as! CalendarDayCell

        let firstOfMonth = startOfMonth(for: currentMonthDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let dayIndex = indexPath.item - leading + 1

        guard dayIndex >= 1, dayIndex <= daysInMonth else {
            cell.configure(dayText: nil, isToday: false, hasEvent: false, isQuiz: false, dotColor: nil)
            return cell
        }

        let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: firstOfMonth) ?? firstOfMonth
        let isToday = calendar.isDateInToday(date)
        let dayItems = items.filter { calendar.isDate($0.dateValue, inSameDayAs: date) }
        let hasEvent = !dayItems.isEmpty
        let isQuiz = dayItems.contains { $0.isQuiz }
        let dotColor: UIColor? = dayItems.last.flatMap { colorForIndex($0.colorIndex) }
        cell.applyTheme(ThemeManager.palette())
        cell.configure(dayText: "\(dayIndex)",
                       isToday: isToday,
                       hasEvent: hasEvent,
                       isQuiz: isQuiz,
                       dotColor: dotColor)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width / 7
        return CGSize(width: width, height: width * 0.85)
    }
}

private extension ScheduleViewController {
    func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)

        countdownLabel.textColor = palette.text
        monthLabel.textColor = palette.text
        weekStack.arrangedSubviews.compactMap { $0 as? UILabel }.forEach { label in
            label.textColor = palette.mutedText
        }

        prevMonthButton.setTitleColor(palette.text, for: .normal)
        nextMonthButton.setTitleColor(palette.text, for: .normal)
        prevMonthButton.titleLabel?.font = AppFont.en(size: 20, weight: .bold)
        nextMonthButton.titleLabel?.font = AppFont.en(size: 20, weight: .bold)

        ThemeManager.stylePrimaryButton(addButton)
        addButton.titleLabel?.font = AppFont.jp(size: 16, weight: .bold)

        calendarCollectionView.layer.cornerRadius = 12
        calendarCollectionView.layer.borderWidth = 1
        calendarCollectionView.layer.borderColor = palette.border.cgColor
        calendarCollectionView.backgroundColor = palette.surface

        tableView.backgroundColor = .clear
        tableView.separatorColor = palette.border
        emptyLabel.font = AppFont.jp(size: 16)
        emptyLabel.textColor = palette.mutedText
    }
}

private struct ScheduleItem: Codable {
    let id: String
    let title: String
    let dateISO: String
    let isQuiz: Bool
    let colorIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, title, dateISO, isQuiz, colorIndex
    }

    init(id: String, title: String, dateISO: String, isQuiz: Bool, colorIndex: Int) {
        self.id = id
        self.title = title
        self.dateISO = dateISO
        self.isQuiz = isQuiz
        self.colorIndex = colorIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        dateISO = try container.decode(String.self, forKey: .dateISO)
        isQuiz = try container.decode(Bool.self, forKey: .isQuiz)
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
    }

    var dateValue: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateISO) ?? Date()
    }
}

private extension ScheduleViewController {
    func presentEdit(for item: ScheduleItem) {
        let alert = UIAlertController(title: "スケジュール編集", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = item.title
            textField.placeholder = "タイトル"
        }

        let contentVC = UIViewController()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let typeSegment = UISegmentedControl(items: ["予定", "小テスト"])
        typeSegment.selectedSegmentIndex = item.isQuiz ? 1 : 0

        let colorStack = UIStackView()
        colorStack.axis = .horizontal
        colorStack.alignment = .center
        colorStack.distribution = .equalSpacing
        colorStack.spacing = 10
        colorStack.translatesAutoresizingMaskIntoConstraints = false

        var colorButtons: [UIButton] = []
        selectedColorIndex = item.colorIndex
        for (index, color) in colorOptions.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.backgroundColor = color
            button.layer.cornerRadius = 12
            button.layer.borderWidth = index == selectedColorIndex ? 2 : 0
            button.layer.borderColor = UIColor.label.cgColor
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 24),
                button.heightAnchor.constraint(equalToConstant: 24),
            ])
            button.addTarget(self, action: #selector(selectColor(_:)), for: .touchUpInside)
            colorButtons.append(button)
            colorStack.addArrangedSubview(button)
        }

        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.date = item.dateValue
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }

        stack.addArrangedSubview(typeSegment)
        stack.addArrangedSubview(colorStack)
        stack.addArrangedSubview(datePicker)
        contentVC.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentVC.view.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: contentVC.view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentVC.view.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: contentVC.view.bottomAnchor, constant: -8),
        ])
        contentVC.preferredContentSize = CGSize(width: 250, height: 230)
        alert.setValue(contentVC, forKey: "contentViewController")

        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            guard let self else { return }
            let title = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = (title?.isEmpty ?? true) ? item.title : title!
            let updatedItem = ScheduleItem(id: item.id,
                                           title: finalTitle,
                                           dateISO: self.isoString(from: datePicker.date),
                                           isQuiz: typeSegment.selectedSegmentIndex == 1,
                                           colorIndex: self.selectedColorIndex)
            var updated = self.loadItems()
            if let idx = updated.firstIndex(where: { $0.id == item.id }) {
                updated[idx] = updatedItem
                self.saveItems(updated)
                self.reloadItems()
            }
        })

        present(alert, animated: true)
    }
}

final class CalendarDayCell: UICollectionViewCell {
    static let reuseID = "CalendarDayCell"

    private let dayLabel = UILabel()
    private let dotView = UIView()
    private var palette: ThemePalette?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(dayLabel)
        contentView.addSubview(dotView)
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dayLabel.font = AppFont.jp(size: 14, weight: .bold)
        dayLabel.textAlignment = .center
        dotView.layer.cornerRadius = 3

        NSLayoutConstraint.activate([
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            dotView.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            dotView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(dayText: String?, isToday: Bool, hasEvent: Bool, isQuiz: Bool, dotColor: UIColor?) {
        dayLabel.text = dayText
        if let _ = dayText {
            dayLabel.textColor = palette?.text ?? .label
        } else {
            dayLabel.textColor = .clear
        }
        dotView.isHidden = !hasEvent
        dotView.backgroundColor = dotColor ?? (isQuiz ? .systemRed : .systemBlue)
        if isToday {
            contentView.backgroundColor = (palette?.surfaceAlt ?? UIColor.systemYellow).withAlphaComponent(0.5)
        } else {
            contentView.backgroundColor = .clear
        }
        contentView.layer.cornerRadius = 8
        if hasEvent {
            contentView.layer.borderWidth = 2
            contentView.layer.borderColor = (palette?.accentStrong ?? UIColor.systemRed).cgColor
        } else {
            contentView.layer.borderWidth = 0
            contentView.layer.borderColor = UIColor.clear.cgColor
        }
    }

    func applyTheme(_ palette: ThemePalette) {
        self.palette = palette
        dayLabel.textColor = palette.text
    }
}

private extension ScheduleViewController {
    func colorForIndex(_ index: Int) -> UIColor? {
        guard index >= 0, index < colorOptions.count else { return nil }
        return colorOptions[index]
    }
}
