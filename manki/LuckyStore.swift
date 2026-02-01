//
//  LuckyStore.swift
//  manki
//
//  Created by Codex.
//

import Foundation

enum LuckyStore {
    private static let historyKey = "manki.lucky.history"
    private static let lastDrawDateKey = "manki.lucky.last_draw_date"
    private static let maxHistory = 200

    struct LuckyEntry: Codable {
        let message: String
        let date: Date
    }

    static func canDrawToday(now: Date = Date()) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: lastDrawDateKey) as? Date else {
            return true
        }
        return !Calendar.current.isDate(last, inSameDayAs: now)
    }

    static func markDraw(message: String, now: Date = Date()) {
        var history = loadHistory()
        history.insert(LuckyEntry(message: message, date: now), at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        UserDefaults.standard.set(now, forKey: lastDrawDateKey)
    }

    static func loadHistory() -> [LuckyEntry] {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([LuckyEntry].self, from: data) else {
            return []
        }
        return decoded
    }
}
