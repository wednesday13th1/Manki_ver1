//
//  AppSpacing.swift
//  manki
//
//  Created by Codex on 2026/02/09.
//

import UIKit

enum AppSpacing {
    private static let baseWidth: CGFloat = 390
    private static let minScale: CGFloat = 0.85
    private static let maxScale: CGFloat = 1.12

    static var scale: CGFloat {
        let width = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let raw = width / baseWidth
        return min(max(raw, minScale), maxScale)
    }

    static func s(_ value: CGFloat) -> CGFloat {
        let scaled = value * scale
        return (scaled * 2).rounded(.toNearestOrAwayFromZero) / 2
    }

    static func s(_ value: Double) -> CGFloat {
        s(CGFloat(value))
    }

    static func s(_ value: Int) -> CGFloat {
        s(CGFloat(value))
    }
}
