//
//  ShibaDayWidget.swift
//  ShibaDayWidget
//

import AppIntents
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
    let id: String?
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No task for today")
                            .font(.subheadline)
                        Text("Create a task in Shiba Day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    let visibleTasks = Array(snapshot.tasks.prefix(visibleTaskLimit))
                    ForEach(visibleTasks.indices, id: \.self) { index in
                        let task = visibleTasks[index]
                        if let taskID = task.id {
                            Toggle(
                                isOn: task.isCompleted,
                                intent: ToggleTaskCompletionIntent(taskID: taskID, day: snapshot.day)
                            ) {
                                Text(task.title)
                            }
                            .toggleStyle(WidgetTaskToggleStyle(
                                brandOrange: brandOrange,
                                title: task.title,
                                time: task.time
                            ))
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(task.isCompleted ? Color.white : brandOrange, brandOrange)
                                taskLabel(task)
                            }
                            .font(.subheadline)
                        }
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "shibaday://today"))
    }

    private func taskLabel(_ task: SharedTaskItem) -> some View {
        HStack(spacing: 6) {
            Text(task.title)
                .lineLimit(1)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? brandOrange : .primary)

            Spacer(minLength: 0)

            if let time = task.time {
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetTaskToggleStyle: ToggleStyle {
    let brandOrange: Color
    let title: String
    let time: String?

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .symbolRenderingMode(.palette)
                .foregroundStyle(configuration.isOn ? Color.white : brandOrange, brandOrange)

            Text(title)
                .lineLimit(1)
                .strikethrough(configuration.isOn)
                .foregroundStyle(configuration.isOn ? brandOrange : .primary)

            Spacer(minLength: 0)

            if let time {
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .accessibilityLabel(title)
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.$isOn.wrappedValue.toggle()
        }
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
                SharedTaskItem(id: nil, title: "Read a chapter", time: nil, isCompleted: false),
                SharedTaskItem(id: nil, title: "Take a walk", time: "5:00 PM", isCompleted: true)
            ]
        )
    }
}
