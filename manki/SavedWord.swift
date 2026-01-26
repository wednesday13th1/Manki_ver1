//
//  SavedWord.swift
//  manki
//
//  Created by Codex.
//

import Foundation

struct SavedWord: Codable {
    let id: String
    let english: String
    let japanese: String
    let illustrationScenario: String?
    let illustrationImageFileName: String?
    var isFavorite: Bool
    var importanceLevel: Int

    enum CodingKeys: String, CodingKey {
        case id
        case english
        case japanese
        case illustrationScenario
        case illustrationImageFileName
        case isFavorite
        case importanceLevel
    }

    init(english: String,
         japanese: String,
         illustrationScenario: String?,
         illustrationImageFileName: String?,
         isFavorite: Bool = false,
         importanceLevel: Int = 1,
         id: String = UUID().uuidString) {
        self.id = id
        self.english = english
        self.japanese = japanese
        self.illustrationScenario = illustrationScenario
        self.illustrationImageFileName = illustrationImageFileName
        self.isFavorite = isFavorite
        self.importanceLevel = importanceLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        english = try container.decode(String.self, forKey: .english)
        japanese = try container.decode(String.self, forKey: .japanese)
        illustrationScenario = try container.decodeIfPresent(String.self, forKey: .illustrationScenario)
        illustrationImageFileName = try container.decodeIfPresent(String.self, forKey: .illustrationImageFileName)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        importanceLevel = try container.decodeIfPresent(Int.self, forKey: .importanceLevel) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(english, forKey: .english)
        try container.encode(japanese, forKey: .japanese)
        try container.encodeIfPresent(illustrationScenario, forKey: .illustrationScenario)
        try container.encodeIfPresent(illustrationImageFileName, forKey: .illustrationImageFileName)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(importanceLevel, forKey: .importanceLevel)
    }
}

struct SavedSet: Codable {
    let id: String
    var name: String
    var wordIDs: [String]
    var folderID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case wordIDs
        case folderID
    }

    init(name: String,
         wordIDs: [String],
         folderID: String? = nil,
         id: String = UUID().uuidString) {
        self.id = id
        self.name = name
        self.wordIDs = wordIDs
        self.folderID = folderID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        wordIDs = try container.decodeIfPresent([String].self, forKey: .wordIDs) ?? []
        folderID = try container.decodeIfPresent(String.self, forKey: .folderID)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(wordIDs, forKey: .wordIDs)
        try container.encodeIfPresent(folderID, forKey: .folderID)
    }
}

struct SetStore {
    static let setsFileName = "saved_sets.json"
    private static let setsBackupKey = "manki.saved_sets.backup"

    static func setsFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(setsFileName)
    }

    static func loadSets() -> [SavedSet] {
        let fileURL = setsFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedSet].self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: setsBackupKey),
           let decoded = try? JSONDecoder().decode([SavedSet].self, from: data) {
            if let encoded = try? JSONEncoder().encode(decoded) {
                try? encoded.write(to: fileURL, options: .atomic)
            }
            return decoded
        }
        return []
    }

    static func saveSets(_ sets: [SavedSet]) {
        let fileURL = setsFileURL()
        guard let data = try? JSONEncoder().encode(sets) else { return }
        try? data.write(to: fileURL, options: .atomic)
        UserDefaults.standard.set(data, forKey: setsBackupKey)
    }
}

struct SavedFolder: Codable {
    let id: String
    var name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    init(name: String, id: String = UUID().uuidString) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

struct FolderStore {
    static let foldersFileName = "saved_folders.json"

    static func foldersFileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        return documents.appendingPathComponent(foldersFileName)
    }

    static func loadFolders() -> [SavedFolder] {
        let fileURL = foldersFileURL()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedFolder].self, from: data) {
            return decoded
        }
        return []
    }

    static func saveFolders(_ folders: [SavedFolder]) {
        let fileURL = foldersFileURL()
        guard let data = try? JSONEncoder().encode(folders) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
