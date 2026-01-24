//
//  ModeViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/24.
//

import UIKit

class ModeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        setupUI()
    }

    private lazy var folderButton: UIButton = makeButton(
        title: "フォルダへ",
        action: #selector(goToFolder)
    )

    private lazy var tabBarButton: UIButton = makeButton(
        title: "スケジュール/履歴へ",
        action: #selector(goToTabBar)
    )

    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [folderButton, tabBarButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7)
        ])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func goToFolder() {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "FolderNavigationController") else {
            return
        }
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func goToTabBar() {
        guard let tabBar = storyboard?.instantiateViewController(withIdentifier: "MainTabBarController") else {
            return
        }
        let nav = UINavigationController(rootViewController: tabBar)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
