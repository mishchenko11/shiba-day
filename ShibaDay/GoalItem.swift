import Foundation
import SwiftData

@Model
final class GoalItem {
    var widgetID: String?
    var title: String
    var targetCount: Int
    var currentCount: Int
    var period: String
    var colorName: String?

    var isCompleted: Bool {
        currentCount >= targetCount
    }

    init(
        title: String,
        targetCount: Int,
        currentCount: Int = 0,
        period: String,
        colorName: String? = nil,
        widgetID: String? = UUID().uuidString
    ) {
        self.widgetID = widgetID
        self.title = title
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.period = period
        self.colorName = colorName
    }
}
