import Foundation
import SwiftData
import WidgetKit

/// Publishes read-only task and goal snapshots for the widgets.
/// SwiftData remains the source of truth in the main app.
@MainActor
enum WidgetSnapshotWriter {
    private static let appGroupIdentifier = "group.com.eireneapps.shibaday"
    private static let taskSnapshotKey = "todayTasksSnapshot"
    private static let goalSnapshotKey = "activeGoalsSnapshot"
    private static let taskWidgetKind = "ShibaDayWidget"
    private static let goalWidgetKind = "ShibaDayGoalsWidget"

    static func refresh(in modelContext: ModelContext) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        do {
            let allTasks = try modelContext.fetch(FetchDescriptor<TaskItem>())
            let today = Calendar.current.startOfDay(for: Date())
            let todaysTasks = allTasks
                .filter { $0.occurs(on: today) }
                .sorted { ($0.time ?? $0.date) < ($1.time ?? $1.date) }
                .map { task in
                    WidgetTaskSnapshotItem(
                        title: task.title,
                        time: task.time?.formatted(date: .omitted, time: .shortened),
                        isCompleted: task.isCompleted(on: today)
                    )
                }

            let snapshot = WidgetTaskSnapshot(day: today, tasks: todaysTasks)
            let data = try JSONEncoder().encode(snapshot)
            sharedDefaults.set(data, forKey: taskSnapshotKey)
            WidgetCenter.shared.reloadTimelines(ofKind: taskWidgetKind)
        } catch {
            // Keep the last valid snapshot if the SwiftData fetch or encoding fails.
        }

        do {
            let allGoals = try modelContext.fetch(FetchDescriptor<GoalItem>())
            let activeGoals = allGoals
                .filter { !$0.isCompleted }
                .sorted {
                    let firstPeriodOrder = periodOrder($0.period)
                    let secondPeriodOrder = periodOrder($1.period)

                    if firstPeriodOrder != secondPeriodOrder {
                        return firstPeriodOrder < secondPeriodOrder
                    }

                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                .map { goal in
                    WidgetGoalSnapshotItem(
                        title: goal.title,
                        currentCount: goal.currentCount,
                        targetCount: goal.targetCount,
                        period: goal.period
                    )
                }

            let snapshot = WidgetGoalSnapshot(goals: activeGoals)
            let data = try JSONEncoder().encode(snapshot)
            sharedDefaults.set(data, forKey: goalSnapshotKey)
            WidgetCenter.shared.reloadTimelines(ofKind: goalWidgetKind)
        } catch {
            // Keep the last valid snapshot if the SwiftData fetch or encoding fails.
        }
    }

    private static func periodOrder(_ period: String) -> Int {
        switch period.lowercased() {
        case "day": 0
        case "week": 1
        case "month": 2
        case "year": 3
        default: 4
        }
    }
}

// Keep these Codable fields in sync with the widget extension's matching payload types.
private struct WidgetTaskSnapshot: Codable {
    let day: Date
    let tasks: [WidgetTaskSnapshotItem]
}

private struct WidgetTaskSnapshotItem: Codable {
    let title: String
    let time: String?
    let isCompleted: Bool
}

private struct WidgetGoalSnapshot: Codable {
    let goals: [WidgetGoalSnapshotItem]
}

private struct WidgetGoalSnapshotItem: Codable {
    let title: String
    let currentCount: Int
    let targetCount: Int
    let period: String
}
