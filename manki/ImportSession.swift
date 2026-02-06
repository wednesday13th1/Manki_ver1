import Foundation

struct ImportRow: Identifiable, Codable {
    // 編集プレビューで扱う行の状態
    enum Status: String, Codable {
        case candidate
        case unclassified
        case confirmed
    }

    let id: UUID
    var term: String
    var meaning: String
    var confidence: Float
    var sourceLine: String
    var status: Status

    init(term: String,
         meaning: String,
         confidence: Float,
         sourceLine: String,
         status: Status) {
        self.id = UUID()
        self.term = term
        self.meaning = meaning
        self.confidence = confidence
        self.sourceLine = sourceLine
        self.status = status
    }

    var isResolved: Bool {
        // term/meaning 両方が埋まっていれば確定扱い
        !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ImportSession: Identifiable, Codable {
    // 再パース時の基準モード
    enum ParseMode: String, Codable {
        case auto
        case delimiter
        case alternating
        case singleLine
    }

    let id: UUID
    let createdAt: Date
    var sourceText: String
    var rows: [ImportRow]
    var mode: ParseMode

    init(sourceText: String, rows: [ImportRow], mode: ParseMode = .auto) {
        self.id = UUID()
        self.createdAt = Date()
        self.sourceText = sourceText
        self.rows = rows
        self.mode = mode
    }
}
