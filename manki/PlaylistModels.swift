import Foundation
import UIKit

enum EmotionTag: String, Codable, CaseIterable {
    case sad
    case happy
    case love
    case angry
    case calm
    case hype
    case nostalgic
    case lonely

    var displayName: String {
        rawValue.capitalized
    }

    var accentColor: UIColor {
        switch self {
        case .sad:
            return UIColor(red: 0.45, green: 0.63, blue: 0.98, alpha: 1)
        case .happy:
            return UIColor(red: 0.99, green: 0.75, blue: 0.22, alpha: 1)
        case .love:
            return UIColor(red: 0.92, green: 0.40, blue: 0.62, alpha: 1)
        case .angry:
            return UIColor(red: 0.88, green: 0.36, blue: 0.31, alpha: 1)
        case .calm:
            return UIColor(red: 0.47, green: 0.76, blue: 0.68, alpha: 1)
        case .hype:
            return UIColor(red: 0.95, green: 0.52, blue: 0.21, alpha: 1)
        case .nostalgic:
            return UIColor(red: 0.67, green: 0.57, blue: 0.86, alpha: 1)
        case .lonely:
            return UIColor(red: 0.55, green: 0.56, blue: 0.67, alpha: 1)
        }
    }
}

enum PlaylistCardDifficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    var displayName: String {
        rawValue.capitalized
    }

    var mappedImportanceLevel: Int {
        switch self {
        case .easy:
            return 1
        case .medium:
            return 3
        case .hard:
            return 5
        }
    }
}

struct PlaylistCard: Codable, Identifiable {
    let id: String
    var word: String
    var meaning: String
    var examplePhrase: String
    var sourceSongTitle: String
    var emotionTag: EmotionTag
    var difficulty: PlaylistCardDifficulty
    var memo: String

    init(id: String = UUID().uuidString,
         word: String,
         meaning: String,
         examplePhrase: String,
         sourceSongTitle: String,
         emotionTag: EmotionTag,
         difficulty: PlaylistCardDifficulty,
         memo: String) {
        self.id = id
        self.word = word
        self.meaning = meaning
        self.examplePhrase = examplePhrase
        self.sourceSongTitle = sourceSongTitle
        self.emotionTag = emotionTag
        self.difficulty = difficulty
        self.memo = memo
    }

    func asSavedWord() -> SavedWord {
        SavedWord(
            english: word,
            japanese: meaning,
            exampleSentence: examplePhrase,
            illustrationScenario: nil,
            illustrationImageFileName: nil,
            isFavorite: false,
            importanceLevel: difficulty.mappedImportanceLevel,
            id: id
        )
    }
}

struct PlaylistSong: Codable, Identifiable {
    let id: String
    var title: String
    var artist: String
    var cards: [PlaylistCard]

    init(id: String = UUID().uuidString,
         title: String,
         artist: String,
         cards: [PlaylistCard] = []) {
        self.id = id
        self.title = title
        self.artist = artist
        self.cards = cards
    }
}

struct Playlist: Codable, Identifiable {
    let id: String
    var title: String
    var description: String
    var emotionTheme: EmotionTag
    var songs: [PlaylistSong]

    init(id: String = UUID().uuidString,
         title: String,
         description: String,
         emotionTheme: EmotionTag,
         songs: [PlaylistSong] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.emotionTheme = emotionTheme
        self.songs = songs
    }

    var allCards: [PlaylistCard] {
        songs.flatMap(\.cards)
    }
}

enum PlaylistStore {
    private static let fileName = "saved_playlists.json"
    private static let backupKey = "manki.saved_playlists.backup"

    static func fileURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }

    static func loadPlaylists() -> [Playlist] {
        let url = fileURL()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: backupKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            if let encoded = try? JSONEncoder().encode(decoded) {
                try? encoded.write(to: url, options: .atomic)
            }
            return decoded
        }
        return []
    }

    static func savePlaylists(_ playlists: [Playlist]) {
        let url = fileURL()
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        try? data.write(to: url, options: .atomic)
        UserDefaults.standard.set(data, forKey: backupKey)
    }
}

extension Playlist {
    func filteredCards(emotion: EmotionTag?, difficulty: PlaylistCardDifficulty?) -> [PlaylistCard] {
        allCards.filter { card in
            let matchesEmotion = emotion == nil || card.emotionTag == emotion
            let matchesDifficulty = difficulty == nil || card.difficulty == difficulty
            return matchesEmotion && matchesDifficulty
        }
    }
}

extension PlaylistSong {
    func filteredCards(emotion: EmotionTag?, difficulty: PlaylistCardDifficulty?) -> [PlaylistCard] {
        cards.filter { card in
            let matchesEmotion = emotion == nil || card.emotionTag == emotion
            let matchesDifficulty = difficulty == nil || card.difficulty == difficulty
            return matchesEmotion && matchesDifficulty
        }
    }
}
