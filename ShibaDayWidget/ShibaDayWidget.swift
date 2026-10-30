//
//  ShibaDayWidget.swift
//  ShibaDayWidget
//

import SwiftUI
import WidgetKit

enum SharedWidgetData {
    static let appGroupIdentifier = "group.com.eireneapps.shibaday"
    static let taskSnapshotKey = "todayTasksSnapshot"
    static let goalSnapshotKey = "activeGoalsSnapshot"
}

private struct SharedTaskSnapshot: Codable {
    let day: Date
    let tasks: [SharedTaskItem]
}

private struct SharedTaskItem: Codable {
    let title: String
    let time: String?
    let isCompleted: Bool
}

private struct ShibaDayEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedTaskSnapshot?
}

private struct ShibaDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShibaDayEntry {
        ShibaDayEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShibaDayEntry) -> Void) {
        let snapshot = readSnapshot(for: .now) ?? .sample
        completion(ShibaDayEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShibaDayEntry>) -> Void) {
        let now = Date()
        let entry = ShibaDayEntry(date: now, snapshot: readSnapshot(for: now))
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(60 * 60)

        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }

    private func readSnapshot(for date: Date) -> SharedTaskSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: SharedWidgetData.appGroupIdentifier),
            let data = defaults.data(forKey: SharedWidgetData.taskSnapshotKey),
            let snapshot = try? JSONDecoder().decode(SharedTaskSnapshot.self, from: data),
            Calendar.current.isDate(snapshot.day, inSameDayAs: date)
        else {
            return nil
        }

        return snapshot
    }
}

private struct ShibaDayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: ShibaDayEntry

    private let brandOrange = Color("brandOrange")

    private var visibleTaskLimit: Int {
        widgetFamily == .systemSmall ? 2 : 3
    }

    private var contentSpacing: CGFloat {
        widgetFamily == .systemSmall ? 7 : 5
    }

    private var remainingTaskCount: Int {
        entry.snapshot?.tasks.filter { !$0.isCompleted }.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            HStack(alignment: .center, spacing: 8) {
                Text("Today's Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if entry.snapshot != nil {
                    Text("\(remainingTaskCount) left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(brandOrange)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 2)

            if let snapshot = entry.snapshot {
                if snapshot.tasks.isEmpty {
                    Text("No tasks planned for today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else if remainingTaskCount == 0 {
                    Text("Everything is done. Nice work!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    let visibleTasks = Array(snapshot.tasks.prefix(visibleTaskLimit))
                    ForEach(visibleTasks.indices, id: \.self) { index in
                        let task = visibleTasks[index]
                        HStack(spacing: 6) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? brandOrange.opacity(0.55) : brandOrange)

                            Text(task.title)
                                .lineLimit(1)
                                .strikethrough(task.isCompleted)
                                .foregroundStyle(task.isCompleted ? .secondary : .primary)

                            Spacer(minLength: 0)

                            if let time = task.time {
                                Text(time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)
                    }

                    if snapshot.tasks.count > visibleTasks.count {
                        Text("+\(snapshot.tasks.count - visibleTasks.count) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Open Shiba Day to load today's tasks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "shibaday://today"))
    }
}

struct ShibaDayWidget: Widget {
    let kind = "ShibaDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShibaDayProvider()) { entry in
            ShibaDayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("See your ShibaDay tasks for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private extension SharedTaskSnapshot {
    static var sample: SharedTaskSnapshot {
        SharedTaskSnapshot(
            day: Calendar.current.startOfDay(for: .now),
            tasks: [
                SharedTaskItem(title: "Read a chapter", time: nil, isCompleted: false),
                SharedTaskItem(title: "Take a walk", time: "5:00 PM", isCompleted: true)
            ]
        )
    }
}
