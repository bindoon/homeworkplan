import SwiftUI
import SwiftData

@main
struct HomeworkPlanApp: App {
    @State private var containerError: String?
    private let modelContainer: ModelContainer
    private let dependencies: AppDependencies
    @State private var dedupeTask: Task<Void, Never>?

    init() {
        #if DEBUG
        CloudKitSchemaInitializer.initializeIfNeeded()
        #endif

        let schema = Schema([
            HomeworkTask.self,
            Subject.self,
            ImportRecord.self,
            RecurringRule.self
        ])
        let configuration = ModelConfiguration(
            cloudKitDatabase: .private("iCloud.app.homeworkplan.HomeworkPlan")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            self.modelContainer = container
            self.dependencies = AppDependencies(context: container.mainContext)
            try dependencies.seedIfNeeded()
        } catch {
            // Fallback to local-only container if CloudKit setup fails (T-01-03 mitigation)
            do {
                let localConfig = ModelConfiguration(cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: localConfig)
                self.modelContainer = container
                self.dependencies = AppDependencies(context: container.mainContext)
                try dependencies.seedIfNeeded()
                self._containerError = State(initialValue: "iCloud 不可用，已切换为仅本地存储。")
            } catch {
                fatalError("无法创建数据容器: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.appDependencies, dependencies)
                .modelContainer(modelContainer)
                .alert("存储错误", isPresented: Binding(
                    get: { containerError != nil },
                    set: { if !$0 { containerError = nil } }
                )) {
                    Button("确定", role: .cancel) {}
                } message: {
                    Text(containerError ?? "")
                }
                .onAppear {
                    registerRemoteChangeObserver()
                }
        }
    }

    private func registerRemoteChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            dedupeTask?.cancel()
            dedupeTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                do {
                    try SubjectDedupeService.mergeDuplicates(context: modelContainer.mainContext)
                } catch {
                    print("Subject dedupe failed: \(error)")
                }
            }
        }
    }
}
