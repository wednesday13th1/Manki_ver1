import UIKit

struct SideMenuItem {
    let route: AppRoute
    let title: String
    let icon: UIImage?
    let isSelected: Bool
    let action: () -> Void
}
