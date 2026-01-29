//
//  StickerStore.swift
//  manki
//
//  Created by Codex.
//

import UIKit

struct SavedSticker: Codable {
    let id: String
    let imageFileName: String
    let createdAt: Date

    init(imageFileName: String,
         id: String = UUID().uuidString,
         createdAt: Date = Date()) {
        self.id = id
        self.imageFileName = imageFileName
        self.createdAt = createdAt
    }
}

enum StickerStore {
    static let stickersFileName = "saved_stickers.json"
    private static let stickersDirectoryName = "stickers"

    static func stickersDirectoryURL(createIfNeeded: Bool = true) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let directory = documents.appendingPathComponent(stickersDirectoryName, isDirectory: true)
        if createIfNeeded, !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory,
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)
        }
        return directory
    }

    static func stickersFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(stickersFileName)
    }

    static func loadStickers() -> [SavedSticker] {
        let fileURL = stickersFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedSticker].self, from: data) {
            return decoded
        }
        return []
    }

    static func saveStickers(_ stickers: [SavedSticker]) {
        let fileURL = stickersFileURL()
        guard let data = try? JSONEncoder().encode(stickers) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func saveStickerImage(_ image: UIImage) -> String? {
        let fileName = "sticker_\(UUID().uuidString).png"
        let url = stickersDirectoryURL().appendingPathComponent(fileName)
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func loadStickerImage(fileName: String) -> UIImage? {
        let url = stickersDirectoryURL(createIfNeeded: false).appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    static func deleteStickerImage(fileName: String) {
        let url = stickersDirectoryURL(createIfNeeded: false).appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}
