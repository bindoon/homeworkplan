import SwiftUI

private enum AppTab: Hashable {
    case home
    case action
    case settings
}

struct MainTabView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .home
    @State private var pendingScreenshot: DetectedScreenshot?
    @State private var showScreenshotImport = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeQueryView()
                .tag(AppTab.home)
                .tabItem {
                    Label("首页", systemImage: "house")
                }

            ActionConsoleView {
                selectedTab = .home
            }
            .tag(AppTab.action)
            .tabItem {
                Label("操作", systemImage: "text.bubble")
            }

            SettingsView()
                .tag(AppTab.settings)
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
                Task { await checkRecentScreenshot() }
            }
        }
        .alert("检测到新截图", isPresented: Binding(
            get: { pendingScreenshot != nil && !showScreenshotImport },
            set: { isPresented in
                if !isPresented {
                    declineScreenshot()
                }
            }
        )) {
            Button("是") {
                acceptScreenshot()
            }
            Button("否", role: .cancel) {
                declineScreenshot()
            }
        } message: {
            Text("是否导入刚才的截图并解析作业？")
        }
        .sheet(isPresented: $showScreenshotImport) {
            NavigationStack {
                ScreenshotImportView(
                    initialImage: pendingScreenshot?.image,
                    onImportComplete: {
                        showScreenshotImport = false
                        pendingScreenshot = nil
                    }
                )
            }
        }
        .accessibilityIdentifier("screenshot-import-alert-host")
    }

    private func checkRecentScreenshot() async {
        guard pendingScreenshot == nil, !showScreenshotImport else { return }
        pendingScreenshot = await ScreenshotDetectService.detectRecentScreenshot()
    }

    private func acceptScreenshot() {
        guard let pendingScreenshot else { return }
        ScreenshotDetectService.markHandled(id: pendingScreenshot.id)
        showScreenshotImport = true
    }

    private func declineScreenshot() {
        if let pendingScreenshot {
            ScreenshotDetectService.markHandled(id: pendingScreenshot.id)
        }
        pendingScreenshot = nil
    }

    private func generateRecurringTasksIfNeeded() {
        guard let dependencies else { return }
        do {
            try dependencies.recurringTaskGenerator.generateIfNeeded()
            Task {
                await dependencies.reminderService.rescheduleAll(
                    using: dependencies.taskRepository,
                    ruleRepository: dependencies.recurringRuleRepository
                )
            }
        } catch {
            print("Recurring task generation failed: \(error)")
        }
    }
}

#Preview {
    MainTabView()
}
