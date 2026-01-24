//
//  MainTabBarController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "戻る",
            style: .plain,
            target: self,
            action: #selector(closeSelf)
        )
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
    }
}
