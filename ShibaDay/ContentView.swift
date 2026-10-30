//
//  ContentView.swift
//  bearsapp
//
//  Created by Irina on 17.09.26.
//

import SwiftUI

private enum AppTab: Hashable {
    case today
    case calendar
    case goals
    case settings
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "house", value: .today) {
                TodayView()
            }
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                CalendarView()
            }
            Tab("Goals", systemImage: "target", value: .goals) {
                GoalView()
            }
            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "shibaday" else { return }

            switch url.host {
            case "today": selectedTab = .today
            case "goals": selectedTab = .goals
            default: break
            }
        }
    }
}

#Preview {
    ContentView()
}
