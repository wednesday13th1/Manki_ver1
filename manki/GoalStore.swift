//
//  GoalStore.swift
//  manki
//
//  Created by Codex.
//

import Foundation

enum GoalPeriod: Int, CaseIterable {
    case day = 0
    case week = 1
    case month = 2
}

enum GoalStore {
    private static let goalMinutesKey = "daily_goal_minutes"
    private static let goalDateKey = "daily_goal_date"
    private static let weeklyGoalMinutesKey = "weekly_goal_minutes"
    private static let weeklyGoalStartDateKey = "weekly_goal_start_date"
    private static let monthlyGoalMinutesKey = "monthly_goal_minutes"
    private static let monthlyGoalStartDateKey = "monthly_goal_start_date"
    private static let lastAchievedAlertDateKey = "daily_goal_achieved_alert_date"

    static func setGoal(minutes: Int, for date: Date = Date()) {
        setGoal(minutes: minutes, period: .day, now: date)
    }

    static func setGoal(minutes: Int, period: GoalPeriod, now: Date = Date()) {
        let defaults = UserDefaults.standard
        let clamped = max(0, minutes)
        let startOfDay = Calendar.current.startOfDay(for: now)
        switch period {
        case .day:
            defaults.set(clamped, forKey: goalMinutesKey)
            defaults.set(startOfDay, forKey: goalDateKey)
        case .week:
            defaults.set(clamped, forKey: weeklyGoalMinutesKey)
            defaults.set(startOfDay, forKey: weeklyGoalStartDateKey)
        case .month:
            defaults.set(clamped, forKey: monthlyGoalMinutesKey)
            defaults.set(startOfDay, forKey: monthlyGoalStartDateKey)
        }
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

    static func goalMinutes(for period: GoalPeriod, now: Date = Date()) -> Int? {
        switch period {
        case .day:
            return goalMinutesForToday(now: now)
        case .week:
            return goalMinutesForCurrentWeek(now: now)
        case .month:
            return goalMinutesForCurrentMonth(now: now)
        }
    }

    static func lastSavedMinutes() -> Int? {
        let minutes = UserDefaults.standard.integer(forKey: goalMinutesKey)
        return minutes > 0 ? minutes : nil
    }

    static func lastSavedMinutes(for period: GoalPeriod) -> Int? {
        switch period {
        case .day:
            return lastSavedMinutes()
        case .week:
            let minutes = UserDefaults.standard.integer(forKey: weeklyGoalMinutesKey)
            return minutes > 0 ? minutes : nil
        case .month:
            let minutes = UserDefaults.standard.integer(forKey: monthlyGoalMinutesKey)
            return minutes > 0 ? minutes : nil
        }
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

    private static func goalMinutesForCurrentWeek(now: Date) -> Int? {
        let defaults = UserDefaults.standard
        guard let start = defaults.object(forKey: weeklyGoalStartDateKey) as? Date else {
            return nil
        }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        guard let end = calendar.date(byAdding: .day, value: 6, to: startDay) else {
            return nil
        }
        let today = calendar.startOfDay(for: now)
        guard today >= startDay, today <= end else {
            return nil
        }
        let minutes = defaults.integer(forKey: weeklyGoalMinutesKey)
        return minutes > 0 ? minutes : nil
    }

    private static func goalMinutesForCurrentMonth(now: Date) -> Int? {
        let defaults = UserDefaults.standard
        guard let start = defaults.object(forKey: monthlyGoalStartDateKey) as? Date else {
            return nil
        }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        guard let end = calendar.date(byAdding: .month, value: 1, to: startDay) else {
            return nil
        }
        let today = calendar.startOfDay(for: now)
        guard today >= startDay, today < end else {
            return nil
        }
        let minutes = defaults.integer(forKey: monthlyGoalMinutesKey)
        return minutes > 0 ? minutes : nil
    }
}
