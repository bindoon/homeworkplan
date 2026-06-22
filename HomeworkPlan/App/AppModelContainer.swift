import Foundation
import SwiftData

enum AppModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            HomeworkTask.self,
            Subject.self,
            ImportRecord.self,
            RecurringRule.self
        ])

        if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
            let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        }

        let config = ModelConfiguration(cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Last-resort bootstrap so the app never shows a blank screen.
    static func makeFallback() -> (container: ModelContainer, statusMessage: String) {
        let schema = Schema([
            HomeworkTask.self,
            Subject.self,
            ImportRecord.self,
            RecurringRule.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: config)
        return (container, "数据加载失败，当前为临时内存模式，重启后数据不会保留。")
    }
}
