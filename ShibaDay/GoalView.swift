import SwiftUI
import SwiftData
import UIKit

struct GoalView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("taskRemindersEnabled") private var taskRemindersEnabled = false
    @AppStorage("goalRemindersEnabled") private var goalRemindersEnabled = false
    @Query private var goals: [GoalItem]
    @State private var showingGoalForm = false
    @State private var goalToEdit: GoalItem?
    @State private var goalToDelete: GoalItem?
    @State private var showingDeleteAlert = false
    @State private var showingCompleted = false

    private var visibleGoals: [GoalItem] {
        goals
            .filter { $0.isCompleted == showingCompleted }
            .sorted {
                let firstPeriodOrder = periodOrder($0.period)
                let secondPeriodOrder = periodOrder($1.period)

                if firstPeriodOrder != secondPeriodOrder {
                    return firstPeriodOrder < secondPeriodOrder
                }

                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            List {
                HStack(spacing: 4) {
                    goalFilterButton("Active", isCompleted: false)
                    goalFilterButton("Completed", isCompleted: true)
                }
                .padding(4)
                .background(Color("brandOrange").opacity(0.12), in: Capsule())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if visibleGoals.isEmpty {
                    VStack(spacing: 14) {
                        Image("shibabox")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .accessibilityHidden(true)

                        Text(showingCompleted ? "No Completed Goals" : "No Active Goals")
                            .font(.headline)
                        Text(showingCompleted
                            ? "Complete a goal and it will appear here."
                            : "Create your first goal with the + button above.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 360, alignment: .center)
                    .padding(.horizontal, 12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                ForEach(visibleGoals) { goal in
                    GoalRow(goal: goal, onProgressChange: refreshRemindersAfterGoalChange)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            goalToDelete = goal
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)

                        Button {
                            goalToEdit = goal
                            showingGoalForm = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Color("brandOrange"))
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Text("My Goals")
                        .font(.title2.bold())

                    Spacer()

                    Button {
                        goalToEdit = nil
                        showingGoalForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color("brandOrange"), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add Goal")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingGoalForm, onDismiss: {
                goalToEdit = nil
            }) {
                AddGoalView(goalToEdit: goalToEdit)
            }
            .alert("Delete this goal?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let goalToDelete {
                        withAnimation {
                            modelContext.delete(goalToDelete)
                        }
                        refreshRemindersAfterGoalChange()
                    }
                    goalToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    goalToDelete = nil
                }
            } message: {
                Text("This goal and its progress will be permanently removed.")
            }
        }
    }

    private func goalFilterButton(_ title: String, isCompleted: Bool) -> some View {
        let isSelected = showingCompleted == isCompleted

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingCompleted = isCompleted
            }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? Color("brandOrange") : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isSelected ? Color(uiColor: .secondarySystemBackground) : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func periodOrder(_ period: String) -> Int {
        switch period.lowercased() {
        case "day": 0
        case "week": 1
        case "month": 2
        case "year": 3
        default: 4
        }
    }

    @MainActor
    private func refreshRemindersAfterGoalChange() {
        try? modelContext.save()
        WidgetSnapshotWriter.refresh(in: modelContext)
        Task {
            await TaskReminderManager.refresh(
                in: modelContext,
                tasksEnabled: taskRemindersEnabled,
                goalsEnabled: goalRemindersEnabled
            )
        }
    }

}

private struct GoalRow: View {
    @Bindable var goal: GoalItem
    let onProgressChange: () -> Void

    private var goalColor: Color {
        Color("goalGreen")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                    Text("\(goal.targetCount) per \(goal.period)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(goal.currentCount), total: Double(goal.targetCount))
                        .tint(goalColor)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(goal.currentCount) / \(goal.targetCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if goal.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(goalColor)
                }
                Spacer()
                Button {
                    guard goal.currentCount > 0 else { return }
                    goal.currentCount -= 1
                    onProgressChange()
                } label: {
                    Image(systemName: "minus.circle")
                }
                .disabled(goal.currentCount == 0)
                .accessibilityLabel("Decrease progress")

                Button {
                    guard goal.currentCount < goal.targetCount else { return }
                    goal.currentCount += 1
                    onProgressChange()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(goal.isCompleted)
                .accessibilityLabel("Increase progress")
            }
            .font(.title3)
            .foregroundStyle(goalColor)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(goalColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    GoalView()
        .modelContainer(for: GoalItem.self, inMemory: true)
}
