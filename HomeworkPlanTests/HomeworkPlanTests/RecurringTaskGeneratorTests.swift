import SwiftData
import XCTest
@testable import HomeworkPlan

@MainActor
final class RecurringTaskGeneratorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var taskRepository: TaskRepository!
    private var ruleRepository: RecurringRuleRepository!
    private var generator: RecurringTaskGenerator!
    private var subject: Subject!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        calendar = cal

        let schema = Schema([HomeworkTask.self, Subject.self, RecurringRule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        taskRepository = TaskRepository(context: context)
        ruleRepository = RecurringRuleRepository(context: context)
        generator = RecurringTaskGenerator(
            context: context,
            taskRepository: taskRepository,
            ruleRepository: ruleRepository
        )

        subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        context.insert(subject)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        generator = nil
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    func testGenerate_createsTaskForDailyRule() throws {
        _ = try ruleRepository.create(
            subject: subject,
            content: "每日练字",
            frequency: .daily
        )

        let today = date(year: 2026, month: 6, day: 22)
        try generator.generateIfNeeded(for: today, calendar: calendar)

        let tasks = try taskRepository.fetchTasks(dueOn: today, includeCompleted: true)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.content, "每日练字")
        XCTAssertEqual(tasks.first?.sourceType, ImportSourceType.recurring.rawValue)
        XCTAssertNotNil(tasks.first?.generationKey)
        XCTAssertNotNil(tasks.first?.recurringRuleId)
    }

    func testGenerate_isIdempotent() throws {
        let rule = try ruleRepository.create(
            subject: subject,
            content: "每日练字",
            frequency: .daily
        )

        let today = date(year: 2026, month: 6, day: 22)
        try generator.generateIfNeeded(for: today, calendar: calendar)
        try generator.generateIfNeeded(for: today, calendar: calendar)

        let tasks = try taskRepository.fetchTasks(dueOn: today, includeCompleted: true)
        XCTAssertEqual(tasks.count, 1)

        let key = HomeworkTask.makeGenerationKey(ruleId: rule.id, date: today, calendar: calendar)
        XCTAssertEqual(tasks.first?.generationKey, key)
    }

    func testGenerate_skipsPausedRule() throws {
        let rule = try ruleRepository.create(
            subject: subject,
            content: "每日练字",
            frequency: .daily
        )
        try ruleRepository.setEnabled(id: rule.id, enabled: false)

        let today = date(year: 2026, month: 6, day: 22)
        try generator.generateIfNeeded(for: today, calendar: calendar)

        let tasks = try taskRepository.fetchTasks(dueOn: today, includeCompleted: true)
        XCTAssertTrue(tasks.isEmpty)
    }

    func testGenerate_respectsWeekdaysFrequency() throws {
        _ = try ruleRepository.create(
            subject: subject,
            content: "工作日练字",
            frequency: .weekdays
        )

        let saturday = date(year: 2026, month: 6, day: 20)
        try generator.generateIfNeeded(for: saturday, calendar: calendar)
        var tasks = try taskRepository.fetchTasks(dueOn: saturday, includeCompleted: true)
        XCTAssertTrue(tasks.isEmpty)

        let monday = date(year: 2026, month: 6, day: 22)
        try generator.generateIfNeeded(for: monday, calendar: calendar)
        tasks = try taskRepository.fetchTasks(dueOn: monday, includeCompleted: true)
        XCTAssertEqual(tasks.count, 1)
    }
}
