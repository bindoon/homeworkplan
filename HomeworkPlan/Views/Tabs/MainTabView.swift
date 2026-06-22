import SwiftUI

struct MainTabView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "calendar")
                }

            AllTasksView()
                .tabItem {
                    Label("全部", systemImage: "list.bullet")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .onAppear {
            generateRecurringTasksIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                generateRecurringTasksIfNeeded()
            }
        }
    }

    private func generateRecurringTasksIfNeeded() {
        guard let dependencies else { return }
        do {
            try dependencies.recurringTaskGenerator.generateIfNeeded()
        } catch {
            print("Recurring task generation failed: \(error)")
        }
    }
}

#Preview {
    MainTabView()
}
