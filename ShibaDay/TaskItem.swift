//
//  TaskItem.swift
//  bearsapp
//
//  Created by Irina on 19.09.26.
//

import Foundation
import SwiftData

@Model
final class TaskItem {
    var widgetID: String?
    var title: String
    var date: Date
    var time: Date?
    var isCompleted: Bool
    var repeatRule: String?

    var reminderMinutesBefore: Int?
    @Relationship(deleteRule: .cascade, inverse: \TaskCompletion.task)
    var completions: [TaskCompletion] = []
 
    init(title: String,
         date: Date,
         time: Date? = nil,
         isCompleted: Bool = false,
         repeatRule: String? = "never",
         reminderMinutesBefore: Int? = nil,
         widgetID: String? = UUID().uuidString
    ) {
        self.widgetID = widgetID
        self.title = title
        self.date = date
        self.time = time
        self.isCompleted = isCompleted
        self.repeatRule = repeatRule
        self.reminderMinutesBefore = reminderMinutesBefore
    }

    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let selectedDay = calendar.startOfDay(for: day)
        let startDay = calendar.startOfDay(for: date)
        guard selectedDay >= startDay else { return false }

        switch repeatRule ?? "never" {
        case "daily":
            return true
        case "weekly":
            return calendar.component(.weekday, from: selectedDay)
                == calendar.component(.weekday, from: startDay)
        case "monthly":
            let targetDay = calendar.component(.day, from: startDay)
            let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDay)?.count ?? targetDay
            return calendar.component(.day, from: selectedDay) == min(targetDay, daysInMonth)
        default:
            return calendar.isDate(startDay, inSameDayAs: selectedDay)
        }
    }

    func isCompleted(on day: Date, calendar: Calendar = .current) -> Bool {
        if (repeatRule ?? "never") == "never" {
            return isCompleted
        }
        return completions.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func setCompleted(_ completed: Bool, on day: Date, in context: ModelContext) {
        if (repeatRule ?? "never") == "never" {
            isCompleted = completed
            return
        }

        let calendar = Calendar.current
        let existing = completions.first { calendar.isDate($0.date, inSameDayAs: day) }
        if completed, existing == nil {
            let completion = TaskCompletion(date: calendar.startOfDay(for: day), task: self)
            context.insert(completion)
        } else if !completed, let existing {
            context.delete(existing)
        }
    }
}

@Model
final class TaskCompletion {
    var date: Date
    var task: TaskItem?

    init(date: Date, task: TaskItem? = nil) {
        self.date = date
        self.task = task
    }
}
