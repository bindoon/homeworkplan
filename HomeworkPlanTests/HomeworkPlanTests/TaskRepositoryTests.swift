import SwiftData
import XCTest
@testable import HomeworkPlan

@MainActor
final class TaskRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: TaskRepository!
    private var subject: Subject!

    override func setUpWithError() throws {
        let schema = Schema([HomeworkTask.self, Subject.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repository = TaskRepository(context: context)

        subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        context.insert(subject)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
    }

    func testMarkComplete_setsIsCompletedAndCompletedAt() throws {
        let task = try repository.create(
            subject: subject,
            content: "练字",
            dueDate: Date()
        )
        try repository.markComplete(id: task.id)

        let fetched = try repository.fetchTask(id: task.id)
        XCTAssertEqual(fetched?.isCompleted, true)
        XCTAssertNotNil(fetched?.completedAt)
    }

    func testMarkIncomplete_clearsCompletedAt() throws {
        let task = try repository.create(
            subject: subject,
            content: "练字",
            dueDate: Date()
        )
        try repository.markComplete(id: task.id)
        try repository.markIncomplete(id: task.id)

        let fetched = try repository.fetchTask(id: task.id)
        XCTAssertEqual(fetched?.isCompleted, false)
        XCTAssertNil(fetched?.completedAt)
    }

    func testDelete_removesTask() throws {
        let task = try repository.create(
            subject: subject,
            content: "练字",
            dueDate: Date()
        )
        try repository.delete(id: task.id)

        let fetched = try repository.fetchTask(id: task.id)
        XCTAssertNil(fetched)
    }

    func testUpdate_changesFields() throws {
        let task = try repository.create(
            subject: subject,
            content: "旧内容",
            notes: "旧备注",
            dueDate: Date()
        )

        let math = Subject(name: "数学", emoji: "🔢", sortOrder: 1, isDefault: true)
        context.insert(math)
        try context.save()

        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        try repository.update(
            id: task.id,
            subject: math,
            content: "新内容",
            notes: "新备注",
            dueDate: newDate
        )

        let fetched = try XCTUnwrap(try repository.fetchTask(id: task.id))
        XCTAssertEqual(fetched.content, "新内容")
        XCTAssertEqual(fetched.notes, "新备注")
        XCTAssertEqual(fetched.subject?.name, "数学")
        XCTAssertEqual(
            Calendar.current.startOfDay(for: fetched.dueDate),
            Calendar.current.startOfDay(for: newDate)
        )
    }

    func testFetchTasksDueOn_returnsOnlyMatchingCalendarDay() throws {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        _ = try repository.create(subject: subject, content: "今天", dueDate: today)
        _ = try repository.create(subject: subject, content: "明天", dueDate: tomorrow)

        let todayTasks = try repository.fetchTasks(dueOn: today, includeCompleted: true)
        XCTAssertEqual(todayTasks.count, 1)
        XCTAssertEqual(todayTasks.first?.content, "今天")
    }

    func testFetchAllGroupedByDate_groupsCorrectly() throws {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        _ = try repository.create(subject: subject, content: "A", dueDate: today)
        _ = try repository.create(subject: subject, content: "B", dueDate: today)
        _ = try repository.create(subject: subject, content: "C", dueDate: tomorrow)

        let grouped = try repository.fetchAllTasksGroupedByDate()
        XCTAssertEqual(grouped.keys.count, 2)
        XCTAssertEqual(grouped[Calendar.current.startOfDay(for: today)]?.count, 2)
        XCTAssertEqual(grouped[Calendar.current.startOfDay(for: tomorrow)]?.count, 1)
    }
}
