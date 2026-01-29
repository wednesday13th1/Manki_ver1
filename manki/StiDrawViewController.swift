//
//  StiDrawViewController.swift
//  manki
//
//  Created by Codex.
//

import UIKit

final class StiDrawViewController: UIViewController {

    private let canvasView = DrawingCanvasView()
    private let clearButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let eraserButton = UIButton(type: .system)
    private let colorStack = UIStackView()
    private let sizeSlider = UISlider()
    var onSave: ((UIImage) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "手書きステッカー"
        view.backgroundColor = .systemBackground
        configureUI()
    }

    private func configureUI() {
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.backgroundColor = UIColor.systemGray6
        canvasView.layer.cornerRadius = 16
        canvasView.clipsToBounds = true

        colorStack.translatesAutoresizingMaskIntoConstraints = false
        colorStack.axis = .horizontal
        colorStack.spacing = 10
        colorStack.distribution = .fillEqually

        let colors: [UIColor] = [.black, .systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple]
        colors.forEach { color in
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.backgroundColor = color
            button.layer.cornerRadius = 10
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.black.withAlphaComponent(0.2).cgColor
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            button.accessibilityValue = color.accessibilityName
            colorStack.addArrangedSubview(button)
        }

        sizeSlider.translatesAutoresizingMaskIntoConstraints = false
        sizeSlider.minimumValue = 2
        sizeSlider.maximumValue = 16
        sizeSlider.value = Float(canvasView.lineWidth)
        sizeSlider.addTarget(self, action: #selector(sizeChanged(_:)), for: .valueChanged)

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setTitle("消す", for: .normal)
        clearButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        eraserButton.translatesAutoresizingMaskIntoConstraints = false
        eraserButton.setTitle("消しゴム", for: .normal)
        eraserButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        eraserButton.addTarget(self, action: #selector(eraserTapped), for: .touchUpInside)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("保存", for: .normal)
        doneButton.titleLabel?.font = AppFont.jp(size: 16, weight: .regular)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [clearButton, eraserButton, doneButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12

        view.addSubview(canvasView)
        view.addSubview(colorStack)
        view.addSubview(sizeSlider)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            canvasView.heightAnchor.constraint(equalTo: canvasView.widthAnchor),

            colorStack.topAnchor.constraint(equalTo: canvasView.bottomAnchor, constant: 12),
            colorStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            colorStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            sizeSlider.topAnchor.constraint(equalTo: colorStack.bottomAnchor, constant: 10),
            sizeSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sizeSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(equalTo: sizeSlider.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func clearTapped() {
        canvasView.clear()
    }

    @objc private func eraserTapped() {
        canvasView.isEraser = true
        updateEraserUI(active: true)
    }

    @objc private func colorTapped(_ sender: UIButton) {
        guard let color = sender.backgroundColor else { return }
        canvasView.strokeColor = color
        canvasView.isEraser = false
        updateEraserUI(active: false)
    }

    @objc private func sizeChanged(_ sender: UISlider) {
        canvasView.lineWidth = CGFloat(sender.value)
    }

    @objc private func doneTapped() {
        guard let image = canvasView.snapshot() else { return }
        onSave?(image)
        navigationController?.popViewController(animated: true)
    }

    private func updateEraserUI(active: Bool) {
        eraserButton.setTitleColor(active ? .systemRed : .label, for: .normal)
    }
}

private final class DrawingCanvasView: UIView {
    private struct Line {
        var points: [CGPoint]
        var color: UIColor
        var width: CGFloat
    }

    private var lines: [Line] = []
    private var currentLine: Line?
    var strokeColor: UIColor = .black
    var lineWidth: CGFloat = 6
    var isEraser: Bool = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        let color = isEraser ? (backgroundColor ?? .white) : strokeColor
        currentLine = Line(points: [point], color: color, width: lineWidth)
        if let line = currentLine {
            lines.append(line)
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        guard var line = currentLine else { return }
        line.points.append(point)
        currentLine = line
        if !lines.isEmpty {
            lines[lines.count - 1] = line
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentLine = nil
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        for line in lines {
            guard let first = line.points.first else { continue }
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(line.width)
            context.setStrokeColor(line.color.cgColor)
            context.beginPath()
            context.move(to: first)
            for point in line.points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }
    }

    func clear() {
        lines.removeAll()
        currentLine = nil
        setNeedsDisplay()
    }

    func snapshot() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { ctx in
            layer.render(in: ctx.cgContext)
        }
    }
}
