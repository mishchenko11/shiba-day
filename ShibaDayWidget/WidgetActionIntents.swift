import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct ToggleTaskCompletionIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle task completion"
    static var openAppWhenRun = false

    @Parameter(title: "Task ID") var taskID: String
    @Parameter(title: "Task day") var day: Date

    init() {
        taskID = ""
        day = .now
    }

    init(taskID: String, day: Date) {
        self.taskID = taskID
        self.day = day
    }

    func perform() async throws -> some IntentResult {
        try await WidgetActionStore.toggleTask(id: taskID, on: day)
        return .result()
    }
}

struct ChangeGoalProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Change goal progress"
    static var openAppWhenRun = false

    @Parameter(title: "Goal ID") var goalID: String
    @Parameter(title: "Change") var amount: Int

    init() {
        goalID = ""
        amount = 0
    }

    init(goalID: String, amount: Int) {
        self.goalID = goalID
        self.amount = amount
    }

    func perform() async throws -> some IntentResult {
        try await WidgetActionStore.changeGoalProgress(id: goalID, by: amount)
        return .result()
    }
}

@MainActor
private enum WidgetActionStore {
    private static let appGroupIdentifier = "group.com.eireneapps.shibaday"

    static func toggleTask(id: String, on day: Date) async throws {
        let container = try makeModelContainer()
        let context = container.mainContext
        let taskID = id
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.widgetID == taskID }
        )

        guard let task = try context.fetch(descriptor).first else {
            throw WidgetActionError.itemNotFound
        }

        let taskDay = Calendar.current.startOfDay(for: day)
        task.setCompleted(!task.isCompleted(on: taskDay), on: taskDay, in: context)
        try context.save()
        WidgetSnapshotWriter.refresh(in: context)
        await refreshReminders(in: context)
    }

    static func changeGoalProgress(id: String, by amount: Int) async throws {
        let container = try makeModelContainer()
        let context = container.mainContext
        let goalID = id
        let descriptor = FetchDescriptor<GoalItem>(
            predicate: #Predicate { $0.widgetID == goalID }
        )

        guard let goal = try context.fetch(descriptor).first else {
            throw WidgetActionError.itemNotFound
        }

        if amount > 0 {
            goal.currentCount = min(goal.currentCount + amount, goal.targetCount)
        } else if amount < 0 {
            goal.currentCount = max(goal.currentCount + amount, 0)
        }

        try context.save()
        WidgetSnapshotWriter.refresh(in: context)
        await refreshReminders(in: context)
    }

    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            TaskItem.self,
            TaskCompletion.self,
            GoalItem.self,
        ])
        let configuration = ModelConfiguration(
            "ShibaDayShared",
            schema: schema,
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func refreshReminders(in context: ModelContext) async {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        await TaskReminderManager.refresh(
            in: context,
            tasksEnabled: defaults.bool(forKey: "taskRemindersEnabled"),
            goalsEnabled: defaults.bool(forKey: "goalRemindersEnabled")
        )
    }
}

private enum WidgetActionError: Error {
    case itemNotFound
}
