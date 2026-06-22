import SwiftUI
import SwiftData

@main
struct HomeworkPlanApp: App {
    @State private var containerError: String?
    private let modelContainer: ModelContainer
    private let dependencies: AppDependencies

    init() {
        let container: ModelContainer
        var statusMessage: String?
        do {
            container = try AppModelContainer.make()
        } catch {
            print("AppModelContainer.make failed: \(error)")
            let fallback = AppModelContainer.makeFallback()
            container = fallback.container
            statusMessage = fallback.statusMessage
        }

        self.modelContainer = container
        self.dependencies = AppDependencies(context: container.mainContext)
        self._containerError = State(initialValue: statusMessage)

        do {
            try dependencies.seedIfNeeded()
        } catch {
            print("Seed defaults failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.appDependencies, dependencies)
                .modelContainer(modelContainer)
                .alert("存储提示", isPresented: Binding(
                    get: { containerError != nil },
                    set: { if !$0 { containerError = nil } }
                )) {
                    Button("确定", role: .cancel) {}
                } message: {
                    Text(containerError ?? "")
                }
        }
    }
}
