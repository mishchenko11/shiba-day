//
//  CalendarView.swift
//  bearsapp
//
//  Created by Irina on 17.09.26.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("taskRemindersEnabled") private var taskRemindersEnabled = false
    @AppStorage("goalRemindersEnabled") private var goalRemindersEnabled = false
    @State private var selectedDate = Date()
    @State private var taskToEdit: TaskItem?
    @State private var taskToDelete: TaskItem?
    @State private var showingDeleteAlert = false
    @Query private var tasks: [TaskItem]
    
    private var selectedDayTasks: [TaskItem] {
        tasks.filter {
            $0.occurs(on: selectedDate)
        }.sorted {
            ($0.time ?? $0.date) < ($1.time ?? $1.date)
        }
    }

    var body: some View {
        List {
            DatePicker(
                "Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Text(selectedDate, style: .date)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if selectedDayTasks.isEmpty {
                Text("No tasks for this day.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(selectedDayTasks) { task in
                HStack {
                    Button {
                        task.setCompleted(
                            !task.isCompleted(on: selectedDate),
                            on: selectedDate,
                            in: modelContext
                        )
                        try? modelContext.save()
                        WidgetSnapshotWriter.refresh(in: modelContext)
                        Task {
                            await TaskReminderManager.refresh(
                                in: modelContext,
                                tasksEnabled: taskRemindersEnabled,
                                goalsEnabled: goalRemindersEnabled
                            )
                        }
                    } label: {
                        Image(systemName: task.isCompleted(on: selectedDate)
                              ? "checkmark.square.fill" : "square")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                task.isCompleted(on: selectedDate) ? Color.white : Color("brandOrange"),
                                Color("brandOrange")
                            )
                            .font(.system(size: 26, weight: .regular))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.isCompleted(on: selectedDate) ? "Mark incomplete: \(task.title)" : "Complete: \(task.title)")
                    .accessibilityValue(task.isCompleted(on: selectedDate) ? "Completed" : "Incomplete")

                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted(on: selectedDate))
                        .foregroundStyle(task.isCompleted(on: selectedDate) ? Color("brandOrange") : Color.primary)

                    Spacer()

                    if let time = task.time {
                        Text(time, style: .time)
                            .font(.subheadline)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        taskToDelete = task
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)

                    Button {
                        taskToEdit = task
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Color("brandOrange"))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .tint(Color("brandOrange"))
        .alert("Are you sure you want to delete this task?", isPresented: $showingDeleteAlert) {
            Button("Yes", role: .destructive) {
                guard let task = taskToDelete else { return }
                withAnimation {
                    modelContext.delete(task)
                }
                try? modelContext.save()
                WidgetSnapshotWriter.refresh(in: modelContext)
                Task {
                    await TaskReminderManager.refresh(
                        in: modelContext,
                        tasksEnabled: taskRemindersEnabled,
                        goalsEnabled: goalRemindersEnabled
                    )
                }
                taskToDelete = nil
            }
            Button("No", role: .cancel) {
                taskToDelete = nil
            }
        } message: {
            Text("This task will be permanently deleted.")
        }
        .sheet(item: $taskToEdit) { task in
            AddTaskView(taskToEdit: task)
        }
    }
}
#Preview {
    CalendarView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
