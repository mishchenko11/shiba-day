import AppIntents
import SwiftUI
import WidgetKit

private struct SharedGoalSnapshot: Codable {
    let goals: [SharedGoalItem]
}

private struct SharedGoalItem: Codable {
    let id: String?
    let title: String
    let currentCount: Int
    let targetCount: Int
    let period: String
}

private struct GoalsWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedGoalSnapshot?
}

private struct GoalsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoalsWidgetEntry {
        GoalsWidgetEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalsWidgetEntry) -> Void) {
        completion(GoalsWidgetEntry(date: .now, snapshot: readSnapshot() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalsWidgetEntry>) -> Void) {
        let now = Date()
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(60 * 60)

        let entry = GoalsWidgetEntry(date: now, snapshot: readSnapshot())
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }

    private func readSnapshot() -> SharedGoalSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: SharedWidgetData.appGroupIdentifier),
            let data = defaults.data(forKey: SharedWidgetData.goalSnapshotKey)
        else {
            return nil
        }

        return try? JSONDecoder().decode(SharedGoalSnapshot.self, from: data)
    }
}

private struct GoalsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: GoalsWidgetEntry

    private let goalGreen = Color("goalGreen")

    private var visibleGoalLimit: Int {
        switch widgetFamily {
        case .systemSmall: 1
        case .systemMedium: 2
        default: 4
        }
    }

    private var allGoals: [SharedGoalItem] {
        entry.snapshot?.goals ?? []
    }

    private var visibleGoals: [SharedGoalItem] {
        Array(allGoals.prefix(visibleGoalLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("My Goals")
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                if let snapshot = entry.snapshot {
                    Text("\(snapshot.goals.count) active")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(goalGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            if let snapshot = entry.snapshot {
                if snapshot.goals.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No goals yet")
                            .font(.subheadline)
                        Text("Create a goal in Shiba Day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ForEach(visibleGoals.indices, id: \.self) { index in
                        goalCard(visibleGoals[index])
                    }

                    if allGoals.count > visibleGoals.count {
                        Text("+\(allGoals.count - visibleGoals.count) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Open Shiba Day to load your goals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "shibaday://goals"))
    }

    private func goalCard(_ goal: SharedGoalItem) -> some View {
        let target = max(goal.targetCount, 1)
        let progress = min(max(goal.currentCount, 0), target)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                Text("\(goal.currentCount)/\(goal.targetCount) · \(goal.period)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(spacing: 8) {
                ProgressView(value: Double(progress), total: Double(target))
                    .tint(goalGreen)

                if let goalID = goal.id {
                    Button(intent: ChangeGoalProgressIntent(goalID: goalID, amount: -1)) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .disabled(goal.currentCount == 0)
                    .foregroundStyle(goalGreen)
                    .accessibilityLabel("Decrease progress for \(goal.title)")

                    Button(intent: ChangeGoalProgressIntent(goalID: goalID, amount: 1)) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .disabled(goal.currentCount >= target)
                    .foregroundStyle(goalGreen)
                    .accessibilityLabel("Increase progress for \(goal.title)")
                }
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShibaDayGoalsWidget: Widget {
    let kind = "ShibaDayGoalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoalsWidgetProvider()) { entry in
            GoalsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Goals")
        .description("Review goals and adjust progress from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private extension SharedGoalSnapshot {
    static var sample: SharedGoalSnapshot {
        SharedGoalSnapshot(goals: [
            SharedGoalItem(id: nil, title: "Read books", currentCount: 1, targetCount: 2, period: "month"),
            SharedGoalItem(id: nil, title: "Work out", currentCount: 1, targetCount: 3, period: "week")
        ])
    }
}
