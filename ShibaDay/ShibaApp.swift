//
//  bearsApp.swift
//  bearsapp
//
//  Created by Irina on 17.09.26.
//

import SwiftUI
import SwiftData

@main
struct shibaApp: App {
    private static let widgetGroupIdentifier = "group.com.eireneapps.shibaday"
    private static let sharedStoreMigrationKey = "didMigrateShibaDayStoreToAppGroup"

    @AppStorage("hasCompletedWelcome")
    private var hasCompletedWelcome = false
    @AppStorage("taskRemindersEnabled")
    private var taskRemindersEnabled = false
    @AppStorage("goalRemindersEnabled")
    private var goalRemindersEnabled = false
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("appTheme")
    private var appTheme: AppAppearance = .system

    var sharedModelContainer: ModelContainer = Self.makeSharedModelContainer()

    private static func makeSharedModelContainer() -> ModelContainer {
        let schema = Schema([
            TaskItem.self,
            TaskCompletion.self,
            GoalItem.self,
        ])
        let sharedConfiguration = ModelConfiguration(
            "ShibaDayShared",
            schema: schema,
            groupContainer: .identifier(widgetGroupIdentifier),
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [sharedConfiguration])
            try migrateExistingStoreIfNeeded(to: container, schema: schema)
            return container
        } catch {
            print("Could not use the shared SwiftData store; keeping the local store: \(error)")
            let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    private static func migrateExistingStoreIfNeeded(
        to sharedContainer: ModelContainer,
        schema: Schema
    ) throws {
        guard let sharedDefaults = UserDefaults(suiteName: widgetGroupIdentifier) else {
            throw SharedStoreError.appGroupUnavailable
        }
        guard !sharedDefaults.bool(forKey: sharedStoreMigrationKey) else { return }

        let sharedContext = sharedContainer.mainContext
        let wasAutosaveEnabled = sharedContext.autosaveEnabled
        sharedContext.autosaveEnabled = false
        defer { sharedContext.autosaveEnabled = wasAutosaveEnabled }
        let sharedTasks = try sharedContext.fetch(FetchDescriptor<TaskItem>())
        let sharedCompletions = try sharedContext.fetch(FetchDescriptor<TaskCompletion>())
        let sharedGoals = try sharedContext.fetch(FetchDescriptor<GoalItem>())

        guard sharedTasks.isEmpty, sharedCompletions.isEmpty, sharedGoals.isEmpty else {
            sharedDefaults.set(true, forKey: sharedStoreMigrationKey)
            return
        }

        let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let localContainer = try ModelContainer(for: schema, configurations: [localConfiguration])
        let localContext = localContainer.mainContext
        let localTasks = try localContext.fetch(FetchDescriptor<TaskItem>())
        let localGoals = try localContext.fetch(FetchDescriptor<GoalItem>())

        guard !localTasks.isEmpty || !localGoals.isEmpty else {
            sharedDefaults.set(true, forKey: sharedStoreMigrationKey)
            return
        }

        for task in localTasks {
            let copiedTask = TaskItem(
                title: task.title,
                date: task.date,
                time: task.time,
                isCompleted: task.isCompleted,
                repeatRule: task.repeatRule,
                reminderMinutesBefore: task.reminderMinutesBefore,
                widgetID: task.widgetID
            )
            sharedContext.insert(copiedTask)

            for completion in task.completions {
                sharedContext.insert(TaskCompletion(date: completion.date, task: copiedTask))
            }
        }

        for goal in localGoals {
            sharedContext.insert(GoalItem(
                title: goal.title,
                targetCount: goal.targetCount,
                currentCount: goal.currentCount,
                period: goal.period,
                colorName: goal.colorName,
                widgetID: goal.widgetID
            ))
        }

        try sharedContext.save()
        sharedDefaults.set(true, forKey: sharedStoreMigrationKey)
    }

    private enum SharedStoreError: Error {
        case appGroupUnavailable
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedWelcome {
                    ContentView()
                        .task {
                            WidgetSnapshotWriter.refresh(in: sharedModelContainer.mainContext)
                            await refreshReminders()
                        }
                        .onChange(of: scenePhase) { _, phase in
                            guard phase == .active else { return }
                            Task {
                                WidgetSnapshotWriter.refresh(in: sharedModelContainer.mainContext)
                                await refreshReminders()
                            }
                        }
                } else {
                    WelcomeView {
                        hasCompletedWelcome = true
                    }
                }
            }
            .preferredColorScheme(appTheme.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func refreshReminders() async {
        let sharedDefaults = UserDefaults(suiteName: Self.widgetGroupIdentifier)
        sharedDefaults?.set(taskRemindersEnabled, forKey: "taskRemindersEnabled")
        sharedDefaults?.set(goalRemindersEnabled, forKey: "goalRemindersEnabled")

        await TaskReminderManager.refresh(
            in: sharedModelContainer.mainContext,
            tasksEnabled: taskRemindersEnabled,
            goalsEnabled: goalRemindersEnabled
        )
    }
}
