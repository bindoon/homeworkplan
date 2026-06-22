import SwiftData
import XCTest
@testable import HomeworkPlan

@MainActor
final class RecurringRuleRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var ruleRepository: RecurringRuleRepository!
    private var taskRepository: TaskRepository!
    private var subject: Subject!

    override func setUpWithError() throws {
        let schema = Schema([HomeworkTask.self, Subject.self, RecurringRule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        ruleRepository = RecurringRuleRepository(context: context)
        taskRepository = TaskRepository(context: context)

        subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        context.insert(subject)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        ruleRepository = nil
        taskRepository = nil
    }

    func testCreateRule_persistsFields() throws {
        let rule = try ruleRepository.create(
            subject: subject,
            content: "每日练字",
            frequency: .daily
        )

        let fetched = try XCTUnwrap(try ruleRepository.fetch(id: rule.id))
        XCTAssertEqual(fetched.content, "每日练字")
        XCTAssertEqual(fetched.subject?.name, "语文")
        XCTAssertEqual(fetched.frequency, .daily)
        XCTAssertTrue(fetched.isEnabled)
    }

    func testPauseResume_togglesIsEnabled() throws {
        let rule = try ruleRepository.create(
            subject: subject,
            content: "每日练字",
            frequency: .daily
        )

        try ruleRepository.setEnabled(id: rule.id, enabled: false)
        var fetched = try XCTUnwrap(try ruleRepository.fetch(id: rule.id))
        XCTAssertFalse(fetched.isEnabled)

        try ruleRepository.setEnabled(id: rule.id, enabled: true)
        fetched = try XCTUnwrap(try ruleRepository.fetch(id: rule.id))
        XCTAssertTrue(fetched.isEnabled)
    }

    func testDeleteRule_doesNotDeleteGeneratedTasks() throws {
        let rule = try ruleRepository.create(
            subject: subject,
            content: "每日练字",
            frequency: .daily
        )

        let generationKey = HomeworkTask.makeGenerationKey(ruleId: rule.id, date: Date())
        let task = try taskRepository.createRecurring(
            subject: subject,
            content: "每日练字",
            dueDate: Date(),
            recurringRuleId: rule.id,
            generationKey: generationKey
        )

        try ruleRepository.delete(id: rule.id)

        let fetchedTask = try taskRepository.fetchTask(id: task.id)
        XCTAssertNotNil(fetchedTask)
        XCTAssertEqual(fetchedTask?.generationKey, generationKey)
    }

    func testFetchByGenerationKey_returnsExistingTask() throws {
        let ruleId = UUID()
        let key = HomeworkTask.makeGenerationKey(ruleId: ruleId, date: Date())

        let task = try taskRepository.createRecurring(
            subject: subject,
            content: "练字",
            dueDate: Date(),
            recurringRuleId: ruleId,
            generationKey: key
        )

        let fetched = try taskRepository.fetchByGenerationKey(key)
        XCTAssertEqual(fetched?.id, task.id)
    }
}
