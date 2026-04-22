import UIKit

enum FontManager {
    enum Role {
        case title
        case navigationTitle
        case button
        case body
        case small
        case display
    }

    private static func scaled(_ size: CGFloat) -> CGFloat {
        size * ThemeManager.textScale
    }

    static func font(_ role: Role, size: CGFloat? = nil, weight: UIFont.Weight = .regular) -> UIFont {
        let pointSize = scaled(size ?? defaultSize(for: role))
        let names = fontNames(for: role, weight: weight)
        for name in names {
            if let font = UIFont(name: name, size: pointSize) {
                return font
            }
        }
        return UIFont.systemFont(ofSize: pointSize, weight: weight)
    }

    static func applyGlobalAppearance() {
        UILabel.appearance().font = font(.body)
        UITextField.appearance().font = font(.body)
        UITextView.appearance().font = font(.body)
        UIButton.appearance().titleLabel?.font = font(.button, weight: .bold)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: font(.small, weight: .bold)], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: font(.small, weight: .bold)], for: .selected)
    }

    private static func defaultSize(for role: Role) -> CGFloat {
        switch role {
        case .title: return 24
        case .navigationTitle: return 18
        case .button: return 16
        case .body: return 15
        case .small: return 12
        case .display: return 28
        }
    }

    private static func fontNames(for role: Role, weight: UIFont.Weight) -> [String] {
        switch role {
        case .display:
            return ["PressStart2P-Regular", "PixelMplus12-Bold", "PixelMplus12-Regular"]
        case .title:
            return ["PixelMplus12-Bold", "PixelMplus12-Regular"]
        case .navigationTitle, .button:
            return weight >= .semibold
                ? ["PixelMplus12-Bold", "PixelMplus10-Bold"]
                : ["PixelMplus12-Regular", "PixelMplus10-Regular"]
        case .body:
            return weight >= .semibold
                ? ["PixelMplus12-Bold", "PixelMplus10-Bold"]
                : ["PixelMplus12-Regular", "PixelMplus10-Regular"]
        case .small:
            return weight >= .semibold
                ? ["PixelMplus10-Bold", "PixelMplus12-Bold"]
                : ["PixelMplus10-Regular", "PixelMplus12-Regular"]
        }
    }
}
