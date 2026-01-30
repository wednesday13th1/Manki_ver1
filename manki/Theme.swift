//
//  Theme.swift
//  manki
//
//  Created by Codex on 2026/01/25.
//

import UIKit

enum AppTheme: String, CaseIterable {
    case yellow
    case green
    case pink
    case blue
    case purple

    var displayName: String {
        switch self {
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .pink: return "Pink"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }
}

struct ThemePalette {
    let background: UIColor
    let surface: UIColor
    let surfaceAlt: UIColor
    let accent: UIColor
    let accentStrong: UIColor
    let border: UIColor
    let text: UIColor
    let mutedText: UIColor
    let dot: UIColor
}

enum AppFont {
    static func jp(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name = weight >= .semibold ? "PixelMplus12-Bold" : "PixelMplus12-Regular"
        if let font = UIFont(name: name, size: size) {
            return font
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func en(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if let font = UIFont(name: "VT323-Regular", size: size) {
            return font
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func title(size: CGFloat) -> UIFont {
        if let font = UIFont(name: "PixelMplus12-Regular", size: size) {
            return font
        }
        return UIFont.systemFont(ofSize: size, weight: .regular)
    }
}

enum ThemeManager {
    static let didChange = Notification.Name("ThemeManagerDidChange")
    private static let storageKey = "manki.theme.current"
    private static let backgroundTag = 9832
    private static var cachedPatterns: [AppTheme: UIImage] = [:]

    static var current: AppTheme {
        get {
            if let raw = UserDefaults.standard.string(forKey: storageKey),
               let theme = AppTheme(rawValue: raw) {
                return theme
            }
            return .yellow
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    static func setTheme(_ theme: AppTheme) {
        current = theme
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func palette(for theme: AppTheme = current) -> ThemePalette {
        switch theme {
        case .yellow:
            return ThemePalette(
                background: UIColor(hex: 0xFFF6DE),
                surface: UIColor(hex: 0xFFF1C7),
                surfaceAlt: UIColor(hex: 0xFFE6A3),
                accent: UIColor(hex: 0xF2B705),
                accentStrong: UIColor(hex: 0xD59A00),
                border: UIColor(hex: 0x2A2A2A),
                text: UIColor(hex: 0x1F1F1F),
                mutedText: UIColor(hex: 0x5A5A5A),
                dot: UIColor(hex: 0xF2B705, alpha: 0.25)
            )
        case .green:
            return ThemePalette(
                background: UIColor(hex: 0xEAF9E6),
                surface: UIColor(hex: 0xDDF3D5),
                surfaceAlt: UIColor(hex: 0xBEE8B2),
                accent: UIColor(hex: 0x70C35B),
                accentStrong: UIColor(hex: 0x4DA645),
                border: UIColor(hex: 0x1E2A1E),
                text: UIColor(hex: 0x1E261E),
                mutedText: UIColor(hex: 0x4F5F4F),
                dot: UIColor(hex: 0x70C35B, alpha: 0.25)
            )
        case .pink:
            return ThemePalette(
                background: UIColor(hex: 0xFBE6F2),
                surface: UIColor(hex: 0xF6D1E7),
                surfaceAlt: UIColor(hex: 0xF1B6D8),
                accent: UIColor(hex: 0xE15BAA),
                accentStrong: UIColor(hex: 0xC83B8E),
                border: UIColor(hex: 0x2A1F2A),
                text: UIColor(hex: 0x281B25),
                mutedText: UIColor(hex: 0x5A4451),
                dot: UIColor(hex: 0xE15BAA, alpha: 0.25)
            )
        case .blue:
            return ThemePalette(
                background: UIColor(hex: 0xE6F2FF),
                surface: UIColor(hex: 0xD6E8FF),
                surfaceAlt: UIColor(hex: 0xB9D9FF),
                accent: UIColor(hex: 0x4DA3FF),
                accentStrong: UIColor(hex: 0x1C7BE6),
                border: UIColor(hex: 0x1C2530),
                text: UIColor(hex: 0x162233),
                mutedText: UIColor(hex: 0x445669),
                dot: UIColor(hex: 0x4DA3FF, alpha: 0.25)
            )
        case .purple:
            return ThemePalette(
                background: UIColor(hex: 0xEFE6FF),
                surface: UIColor(hex: 0xE2D6FF),
                surfaceAlt: UIColor(hex: 0xCDBBFF),
                accent: UIColor(hex: 0x8B6DFF),
                accentStrong: UIColor(hex: 0x6A4DDA),
                border: UIColor(hex: 0x211C2C),
                text: UIColor(hex: 0x1F1C2B),
                mutedText: UIColor(hex: 0x4C445C),
                dot: UIColor(hex: 0x8B6DFF, alpha: 0.25)
            )
        }
    }

    static func applyBackground(to view: UIView) {
        let palette = palette()
        view.backgroundColor = palette.background

        let patternView: UIView
        if let existing = view.viewWithTag(backgroundTag) {
            patternView = existing
        } else {
            patternView = UIView()
            patternView.tag = backgroundTag
            patternView.translatesAutoresizingMaskIntoConstraints = false
            patternView.isUserInteractionEnabled = false
            patternView.alpha = 0.4
            view.insertSubview(patternView, at: 0)
            NSLayoutConstraint.activate([
                patternView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                patternView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                patternView.topAnchor.constraint(equalTo: view.topAnchor),
                patternView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }

        if let cached = cachedPatterns[current] {
            patternView.backgroundColor = UIColor(patternImage: cached)
        } else {
            let image = makePatternImage(dotColor: palette.dot, background: .clear)
            cachedPatterns[current] = image
            patternView.backgroundColor = UIColor(patternImage: image)
        }
    }

    static func applyNavigationAppearance(to navigationController: UINavigationController?) {
        guard let navigationController else { return }
        let palette = palette()
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = palette.surface
        appearance.titleTextAttributes = [
            .foregroundColor: palette.text,
            .font: AppFont.jp(size: 18, weight: .bold)
        ]
        let barAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: palette.text,
            .font: AppFont.jp(size: 14, weight: .bold)
        ]
        appearance.shadowColor = palette.border
        appearance.buttonAppearance.normal.titleTextAttributes = barAttributes
        appearance.buttonAppearance.highlighted.titleTextAttributes = barAttributes
        appearance.doneButtonAppearance.normal.titleTextAttributes = barAttributes
        appearance.doneButtonAppearance.highlighted.titleTextAttributes = barAttributes
        appearance.backButtonAppearance.normal.titleTextAttributes = barAttributes
        appearance.backButtonAppearance.highlighted.titleTextAttributes = barAttributes
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance
        navigationController.navigationBar.tintColor = palette.text
    }

    static func applySearchBar(_ searchBar: UISearchBar) {
        let palette = palette()
        searchBar.searchTextField.backgroundColor = palette.surface
        searchBar.searchTextField.textColor = palette.text
        searchBar.searchTextField.font = AppFont.jp(size: 14)
        searchBar.searchTextField.layer.cornerRadius = 12
        searchBar.searchTextField.layer.borderWidth = 1
        searchBar.searchTextField.layer.borderColor = palette.border.cgColor
        searchBar.searchTextField.clipsToBounds = true
        searchBar.tintColor = palette.text
    }

    static func stylePrimaryButton(_ button: UIButton) {
        let palette = palette()
        button.backgroundColor = palette.accent
        button.setTitleColor(palette.text, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = palette.border.cgColor
        button.layer.shadowColor = palette.border.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
    }

    static func styleSecondaryButton(_ button: UIButton) {
        let palette = palette()
        button.backgroundColor = palette.surface
        button.setTitleColor(palette.text, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = palette.border.cgColor
    }

    private static func makePatternImage(dotColor: UIColor, background: UIColor) -> UIImage {
        let size = CGSize(width: 14, height: 14)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            dotColor.setFill()
            let dotRect = CGRect(x: 6, y: 6, width: 2, height: 2)
            context.cgContext.fillEllipse(in: dotRect)
        }
    }
}

private extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
