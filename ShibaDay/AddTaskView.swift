//
//  AddTaskView.swift
//  bearsapp
//
//  Created by Irina on 18.09.26.
//

import SwiftUI
import SwiftData
import UIKit

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("taskRemindersEnabled") private var taskRemindersEnabled = false
    @AppStorage("goalRemindersEnabled") private var goalRemindersEnabled = false
    @State private var title = ""
    @State private var date = Date()
    @State private var time = Date()
    @State private var includeTime = false
    @State private var repeatRule = "never"
    @State private var showingSaveError = false
    @FocusState private var titleFieldFocused: Bool
    private let taskToEdit: TaskItem?
    private let repeatOptions = [
        ("never", "Does not repeat"),
        ("daily", "Every day"),
        ("weekly", "Every week"),
        ("monthly", "Every month")
    ]

    private var isTitleEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(taskToEdit: TaskItem? = nil) {
        self.taskToEdit = taskToEdit
        
        _title = State(initialValue: taskToEdit?.title ?? "")
        _date = State(initialValue: taskToEdit?.date ?? Date())
        _time = State(initialValue: taskToEdit?.time ?? Date())
        _includeTime = State(initialValue: taskToEdit?.time != nil)
        _repeatRule = State(initialValue: taskToEdit?.repeatRule ?? "never")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        TextField("Task title", text: $title)
                            .focused($titleFieldFocused)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture().onEnded { titleFieldFocused = true }
                            )

                        Divider()
                            .padding(.leading, 16)

                        DatePicker(
                            "Date",
                            selection: $date,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .contentShape(Rectangle())

                        Divider()
                            .padding(.leading, 16)

                        Picker("Repeat", selection: $repeatRule) {
                            ForEach(repeatOptions, id: \.0) { option in
                                Text(option.1).tag(option.0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .contentShape(Rectangle())

                        Divider()
                            .padding(.leading, 16)

                        Toggle("Add time", isOn: $includeTime)
                            .padding(16)
                            .contentShape(Rectangle())

                        if includeTime {
                            Divider()
                                .padding(.leading, 16)

                            DatePicker(
                                "Time",
                                selection: $time,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .contentShape(Rectangle())
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color("brandOrange").opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 5)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: saveTask) {
                    Text(taskToEdit == nil ? "Save Task" : "Save Changes")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .background(Color("brandOrange"), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isTitleEmpty)
                .opacity(isTitleEmpty ? 0.5 : 1)
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .navigationTitle(taskToEdit == nil ? "Add Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color("brandOrange"))
            .alert("Couldn't save task", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your task hasn't been saved. Please try again.")
            }
        }
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let scheduledTime = includeTime ? calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: day
        ) : nil
        let task: TaskItem
        if let taskToEdit {
            task = taskToEdit
            task.title = trimmedTitle
            task.date = day
            task.time = scheduledTime
            task.repeatRule = repeatRule
        } else {
            task = TaskItem(
                title: trimmedTitle,
                date: day,
                time: scheduledTime,
                repeatRule: repeatRule
            )
            modelContext.insert(task)
        }

        do {
            try modelContext.save()
            WidgetSnapshotWriter.refresh(in: modelContext)
            Task {
                await TaskReminderManager.refresh(
                    in: modelContext,
                    tasksEnabled: taskRemindersEnabled,
                    goalsEnabled: goalRemindersEnabled
                )
                dismiss()
            }
        } catch {
            showingSaveError = true
        }
    }
}

#Preview {
    AddTaskView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
