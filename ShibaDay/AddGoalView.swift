import SwiftUI
import SwiftData
import UIKit

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("taskRemindersEnabled") private var taskRemindersEnabled = false
    @AppStorage("goalRemindersEnabled") private var goalRemindersEnabled = false
    @State private var title: String
    @State private var targetCount: Int
    @State private var period: String
    @State private var showingSaveError = false
    @FocusState private var titleFieldFocused: Bool

    private let goalToEdit: GoalItem?
    private let periods = ["day", "week", "month", "year"]

    private var isTitleEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(goalToEdit: GoalItem? = nil) {
        self.goalToEdit = goalToEdit
        _title = State(initialValue: goalToEdit?.title ?? "")
        _targetCount = State(initialValue: goalToEdit?.targetCount ?? 2)
        _period = State(initialValue: goalToEdit?.period ?? "month")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        TextField("What do you want to achieve?", text: $title)
                            .focused($titleFieldFocused)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture().onEnded { titleFieldFocused = true }
                            )

                        Divider()
                            .padding(.leading, 16)

                        Stepper("Target: \(targetCount)", value: $targetCount, in: 1...100)
                            .padding(16)

                        Divider()
                            .padding(.leading, 16)

                        Picker("Period", selection: $period) {
                            ForEach(periods, id: \.self) { item in
                                Text(item.capitalized).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .contentShape(Rectangle())
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
                Button(action: saveGoal) {
                    Text(goalToEdit == nil ? "Save Goal" : "Save Changes")
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
            .navigationTitle(goalToEdit == nil ? "Add Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color("brandOrange"))
            .alert("Couldn't save goal", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your goal hasn't been saved. Please try again.")
            }
        }
    }

    private func saveGoal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let goal: GoalItem
        if let goalToEdit {
            goal = goalToEdit
            goal.title = trimmedTitle
            goal.targetCount = targetCount
            goal.period = period
        } else {
            goal = GoalItem(
                title: trimmedTitle,
                targetCount: targetCount,
                period: period
            )
            modelContext.insert(goal)
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
    AddGoalView()
        .modelContainer(for: GoalItem.self, inMemory: true)
}
