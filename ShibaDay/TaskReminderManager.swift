import Foundation
import SwiftData
import UserNotifications

@MainActor
enum TaskReminderManager {
    private static let taskIdentifierPrefix = "shibaapp.task-reminder."
    private static let goalIdentifierPrefix = "shibaapp.goal-reminder."
    private static let maximumPendingReminders = 64
    private static let dateOnlyTaskReminderHour = 8
    private static let timedTaskReminderLeadMinutes = 60
    private static let goalReminderHour = 9
    private static let monday = 2
    private static let wednesday = 4

    private struct ReminderCandidate {
        let identifierPrefix: String
        let title: String
        let fireDate: Date
        let message: String
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func refresh(
        in modelContext: ModelContext,
        tasksEnabled: Bool,
        goalsEnabled: Bool
    ) async {
        do {
            let tasks = tasksEnabled
                ? try modelContext.fetch(FetchDescriptor<TaskItem>())
                : []
            let goals = goalsEnabled
                ? try modelContext.fetch(FetchDescriptor<GoalItem>())
                : []
            await refresh(for: tasks, goals: goals, tasksEnabled: tasksEnabled, goalsEnabled: goalsEnabled)
        } catch {
            return
        }
    }

    private static func refresh(
        for tasks: [TaskItem],
        goals: [GoalItem],
        tasksEnabled: Bool,
        goalsEnabled: Bool
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let oldManagedIDs = pending
            .map(\.identifier)
            .filter {
                $0.hasPrefix(taskIdentifierPrefix) || $0.hasPrefix(goalIdentifierPrefix)
            }
        center.removePendingNotificationRequests(withIdentifiers: oldManagedIDs)

        guard tasksEnabled || goalsEnabled else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else {
            return
        }

        let now = Date()
        var candidateGroups: [[ReminderCandidate]] = []
        if tasksEnabled {
            candidateGroups += tasks.map { upcomingTaskReminders(for: $0, after: now) }
        }
        if goalsEnabled {
            candidateGroups += goals.map { upcomingGoalReminders(for: $0, after: now) }
        }

        let candidates = fairlySelectedCandidates(
            from: candidateGroups,
            limit: maximumPendingReminders
        )
        for candidate in candidates.sorted(by: { $0.fireDate < $1.fireDate }) {
            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: candidate.fireDate
            )
            components.calendar = Calendar.current
            components.timeZone = Calendar.current.timeZone

            let content = UNMutableNotificationContent()
            content.title = candidate.title
            content.body = candidate.message
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: candidate.identifierPrefix + UUID().uuidString,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {

            }
        }
    }

    private static func fairlySelectedCandidates(
        from groups: [[ReminderCandidate]],
        limit: Int
    ) -> [ReminderCandidate] {
        let orderedGroups = groups
            .map { $0.sorted(by: { $0.fireDate < $1.fireDate }) }
            .filter { !$0.isEmpty }
            .sorted { $0[0].fireDate < $1[0].fireDate }

        var selected: [ReminderCandidate] = []
        var round = 0

        while selected.count < limit {
            let nextCandidates = orderedGroups.compactMap { group in
                group.indices.contains(round) ? group[round] : nil
            }
            guard !nextCandidates.isEmpty else { break }
            selected.append(contentsOf: nextCandidates.prefix(limit - selected.count))
            round += 1
        }

        return selected
    }

    private static func upcomingTaskReminders(
        for task: TaskItem,
        after now: Date,
        calendar: Calendar = .current
    ) -> [ReminderCandidate] {
        let repeatRule = task.repeatRule ?? "never"
        if repeatRule == "never" {
            return taskReminder(for: task, on: task.date, after: now, calendar: calendar)
                .map { [$0] } ?? []
        }

        let firstDay = calendar.startOfDay(for: now)
        return (0..<366).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  task.occurs(on: day, calendar: calendar) else {
                return nil
            }
            return taskReminder(for: task, on: day, after: now, calendar: calendar)
        }
    }

    private static func taskReminder(
        for task: TaskItem,
        on day: Date,
        after now: Date,
        calendar: Calendar
    ) -> ReminderCandidate? {
        guard !task.isCompleted(on: day, calendar: calendar) else { return nil }

        if let taskTime = task.time {
            let time = calendar.dateComponents([.hour, .minute], from: taskTime)
            guard let dueDate = calendar.date(
                bySettingHour: time.hour ?? 0,
                minute: time.minute ?? 0,
                second: 0,
                of: day
            ) else {
                return nil
            }

            let fireDate = dueDate.addingTimeInterval(-Double(timedTaskReminderLeadMinutes * 60))
            guard fireDate > now else { return nil }
            return ReminderCandidate(
                identifierPrefix: taskIdentifierPrefix,
                title: task.title,
                fireDate: fireDate,
                message: "Starting in \(timedTaskReminderLeadMinutes) minutes."
            )
        }

        guard let fireDate = calendar.date(
            bySettingHour: dateOnlyTaskReminderHour,
            minute: 0,
            second: 0,
            of: day
        ), fireDate > now else {
            return nil
        }

        return ReminderCandidate(
            identifierPrefix: taskIdentifierPrefix,
            title: task.title,
            fireDate: fireDate,
            message: "This task is planned for today."
        )
    }

    private static func upcomingGoalReminders(
        for goal: GoalItem,
        after now: Date,
        calendar: Calendar = .current
    ) -> [ReminderCandidate] {
        guard !goal.isCompleted else { return [] }

        let firstDay = calendar.startOfDay(for: now)
        return (0..<366).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            return goalReminder(for: goal, on: day, after: now, calendar: calendar)
        }
    }

    private static func goalReminder(
        for goal: GoalItem,
        on day: Date,
        after now: Date,
        calendar: Calendar
    ) -> ReminderCandidate? {
        let weekday = calendar.component(.weekday, from: day)
        let dayOfMonth = calendar.component(.day, from: day)
        let hour: Int

        switch goal.period.lowercased() {
        case "day":
            hour = dateOnlyTaskReminderHour
        case "week":
            guard weekday == wednesday else { return nil }
            hour = goalReminderHour
        case "month":
            guard weekday == monday else { return nil }
            hour = goalReminderHour
        case "year":
            guard dayOfMonth == 1 else { return nil }
            hour = goalReminderHour
        default:
            return nil
        }

        guard let fireDate = calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: day
        ), fireDate > now else {
            return nil
        }

        return ReminderCandidate(
            identifierPrefix: goalIdentifierPrefix,
            title: goal.title,
            fireDate: fireDate,
            message: "Progress: \(goal.currentCount) of \(goal.targetCount). Keep going."
        )
    }
}
