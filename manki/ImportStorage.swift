import Foundation

enum DuplicatePolicy {
    case overwrite
    case skip
    case keepBoth
}

protocol VocabStorage {
    // 既存の単語群を取得
    func loadAll() -> [SavedWord]
    // 単語群を一括保存
    func saveAll(_ words: [SavedWord])
}

struct JsonVocabStorage: VocabStorage {
    private let fileName = "saved_words.json"
    private let backupKey = "manki.saved_words.backup"

    private func fileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }

    func loadAll() -> [SavedWord] {
        let url = fileURL()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: backupKey),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            if let encoded = try? JSONEncoder().encode(decoded) {
                try? encoded.write(to: url, options: .atomic)
            }
            return decoded
        }
        return []
    }

    func saveAll(_ words: [SavedWord]) {
        let url = fileURL()
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: url, options: .atomic)
        UserDefaults.standard.set(data, forKey: backupKey)
    }
}

struct ImportSaver {
    // ImportRow から SavedWord を生成して保存する
    static func save(rows: [ImportRow],
                     storage: VocabStorage,
                     duplicatePolicy: DuplicatePolicy) -> (added: Int, skipped: Int) {
        let resolved = rows.filter { $0.isResolved }
        let existing = storage.loadAll()
        var merged = existing
        var skipped = 0
        var added = 0

        for row in resolved {
            let term = row.term.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = row.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            if term.isEmpty || meaning.isEmpty {
                continue
            }
            if let index = merged.firstIndex(where: { $0.english.lowercased() == term.lowercased() }) {
                switch duplicatePolicy {
                case .overwrite:
                    let updated = SavedWord(english: term,
                                            japanese: meaning,
                                            illustrationScenario: merged[index].illustrationScenario,
                                            illustrationImageFileName: merged[index].illustrationImageFileName,
                                            isFavorite: merged[index].isFavorite,
                                            importanceLevel: merged[index].importanceLevel,
                                            id: merged[index].id)
                    merged[index] = updated
                    added += 1
                case .skip:
                    skipped += 1
                case .keepBoth:
                    merged.append(SavedWord(english: term,
                                            japanese: meaning,
                                            illustrationScenario: nil,
                                            illustrationImageFileName: nil,
                                            isFavorite: false,
                                            importanceLevel: 1))
                    added += 1
                }
            } else {
                merged.append(SavedWord(english: term,
                                        japanese: meaning,
                                        illustrationScenario: nil,
                                        illustrationImageFileName: nil,
                                        isFavorite: false,
                                        importanceLevel: 1))
                added += 1
            }
        }

        storage.saveAll(merged)
        return (added: added, skipped: skipped)
    }
}
