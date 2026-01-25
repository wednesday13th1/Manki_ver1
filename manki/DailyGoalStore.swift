//
//  DailyGoalStore.swift
//  manki
//
//  Created by Codex.
//

import Foundation

enum DailyGoalStore {
    private static let lastPromptDateKey = "last_goal_prompt_date"
    private static let goalMinutesKey = "daily_goal_minutes"
    private static let goalDateKey = "daily_goal_date"
    private static let lastAchievedAlertDateKey = "daily_goal_achieved_alert_date"

    static func shouldPromptToday(now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastPromptDateKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: now) {
            return false
        }
        return true
    }

    static func markPromptedToday(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: lastPromptDateKey)
    }

    static func setGoal(minutes: Int, for date: Date = Date()) {
        let defaults = UserDefaults.standard
        defaults.set(max(0, minutes), forKey: goalMinutesKey)
        defaults.set(date, forKey: goalDateKey)
    }

    static func goalMinutesForToday(now: Date = Date()) -> Int? {
        let defaults = UserDefaults.standard
        guard let goalDate = defaults.object(forKey: goalDateKey) as? Date,
              Calendar.current.isDate(goalDate, inSameDayAs: now) else {
            return nil
        }
        let minutes = defaults.integer(forKey: goalMinutesKey)
        return minutes > 0 ? minutes : nil
    }

    static func shouldShowAchievedAlert(now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastAchievedAlertDateKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: now) {
            return false
        }
        return true
    }

    static func markAchievedAlertShown(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: lastAchievedAlertDateKey)
    }
}
