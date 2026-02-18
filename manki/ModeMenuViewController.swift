import UIKit

private final class HeartActionButton: UIButton {
    private let fillLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private var fillColor: UIColor = .systemYellow
    private var borderColor: UIColor = .black

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.insertSublayer(fillLayer, at: 0)
        layer.insertSublayer(borderLayer, above: fillLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.insertSublayer(fillLayer, at: 0)
        layer.insertSublayer(borderLayer, above: fillLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = bounds.insetBy(dx: 0.6, dy: 0.6)
        let path = heartBezierPath(in: rect).cgPath
        fillLayer.frame = bounds
        fillLayer.path = path
        fillLayer.fillColor = fillColor.cgColor
        fillLayer.strokeColor = UIColor.clear.cgColor

        borderLayer.frame = bounds
        borderLayer.path = path
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = borderColor.cgColor
        borderLayer.lineWidth = 1.8

        layer.shadowPath = path
        layer.shadowColor = borderColor.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 3
    }

    func applyHeartStyle(fill: UIColor, border: UIColor, textColor: UIColor) {
        fillColor = fill
        borderColor = border
        setTitleColor(textColor, for: .normal)
        setNeedsLayout()
    }

    private func heartBezierPath(in rect: CGRect) -> UIBezierPath {
        let w = rect.width
        let h = rect.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.95))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.38),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.86),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.60))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.28, y: rect.minY + h * 0.10),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.20),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.10))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.23),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.37, y: rect.minY + h * 0.10),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.46, y: rect.minY + h * 0.18))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.10),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.54, y: rect.minY + h * 0.18),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.63, y: rect.minY + h * 0.10))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.38),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.10),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.20))
        path.addCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.95),
                      controlPoint1: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.60),
                      controlPoint2: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.86))
        path.close()
        return path
    }
}

final class ModeMenuViewController: UIViewController {
    private let menuTitle: String
    private let firstButtonTitle: String
    private let secondButtonTitle: String

    var onFirstTapped: (() -> Void)?
    var onSecondTapped: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let firstButton = HeartActionButton(frame: .zero)
    private let secondButton = HeartActionButton(frame: .zero)
    private var themeObserver: NSObjectProtocol?

    init(menuTitle: String, firstButtonTitle: String, secondButtonTitle: String) {
        self.menuTitle = menuTitle
        self.firstButtonTitle = firstButtonTitle
        self.secondButtonTitle = secondButtonTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        applyTheme()
        themeObserver = NotificationCenter.default.addObserver(
            forName: ThemeManager.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    deinit {
        if let observer = themeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func configureUI() {
        navigationItem.title = menuTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "戻る",
            style: .plain,
            target: self,
            action: #selector(closeSelf)
        )

        titleLabel.text = menuTitle
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "Select Action"
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        firstButton.setTitle(firstButtonTitle, for: .normal)
        firstButton.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        firstButton.translatesAutoresizingMaskIntoConstraints = false
        firstButton.addTarget(self, action: #selector(handleFirstTap), for: .touchUpInside)

        secondButton.setTitle(secondButtonTitle, for: .normal)
        secondButton.titleLabel?.font = AppFont.jp(size: 18, weight: .bold)
        secondButton.translatesAutoresizingMaskIntoConstraints = false
        secondButton.addTarget(self, action: #selector(handleSecondTap), for: .touchUpInside)

        let buttonsRow = UIStackView(arrangedSubviews: [firstButton, secondButton])
        buttonsRow.axis = .horizontal
        buttonsRow.distribution = .fillEqually
        buttonsRow.alignment = .center
        buttonsRow.spacing = AppSpacing.s(14)
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, buttonsRow])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = AppSpacing.s(14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(36)),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(36)),
            buttonsRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            firstButton.heightAnchor.constraint(equalToConstant: 104),
            secondButton.heightAnchor.constraint(equalToConstant: 104),
        ])
    }

    private func applyTheme() {
        let palette = ThemeManager.palette()
        ThemeManager.applyBackground(to: view)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        titleLabel.font = AppFont.title(size: 22)
        titleLabel.textColor = palette.text
        subtitleLabel.font = AppFont.jp(size: 16, weight: .bold)
        subtitleLabel.textColor = palette.mutedText
        firstButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        secondButton.titleLabel?.font = AppFont.jp(size: 15, weight: .bold)
        firstButton.applyHeartStyle(fill: palette.accent, border: palette.border, textColor: palette.text)
        secondButton.applyHeartStyle(fill: palette.surfaceAlt, border: palette.border, textColor: palette.text)
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
    }

    @objc private func handleFirstTap() {
        dismiss(animated: false) { [weak self] in
            self?.onFirstTapped?()
        }
    }

    @objc private func handleSecondTap() {
        dismiss(animated: false) { [weak self] in
            self?.onSecondTapped?()
        }
    }
}
