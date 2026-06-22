import SwiftData
import XCTest
@testable import HomeworkPlan

@MainActor
final class HomeQueryViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: TaskRepository!
    private var viewModel: HomeQueryViewModel!
    private var subject: Subject!
    private var mathSubject: Subject!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        calendar = Calendar.current
        let schema = Schema([HomeworkTask.self, Subject.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repository = TaskRepository(context: context)
        viewModel = HomeQueryViewModel()

        subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        mathSubject = Subject(name: "数学", emoji: "🔢", sortOrder: 1, isDefault: true)
        context.insert(subject)
        context.insert(mathSubject)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
        viewModel = nil
    }

    func testReload_groupsSelectedDateBySubject() throws {
        let today = Date()
        _ = try repository.create(subject: subject, content: "抄课文", dueDate: today)
        _ = try repository.create(subject: mathSubject, content: "练习册 P15", dueDate: today)

        viewModel.reload(using: repository)

        XCTAssertEqual(viewModel.subjectGroups.count, 2)
        XCTAssertEqual(viewModel.subjectGroups[0].subject.name, "语文")
        XCTAssertEqual(viewModel.subjectGroups[1].subject.name, "数学")
        XCTAssertTrue(viewModel.isSubjectExpanded(subject.id))
        XCTAssertTrue(viewModel.isSubjectExpanded(mathSubject.id))
    }

    func testReload_excludesSelectedDateFromHistory() throws {
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            XCTFail("Could not compute yesterday")
            return
        }

        _ = try repository.create(subject: subject, content: "今日任务", dueDate: today)
        _ = try repository.create(subject: subject, content: "昨日任务", dueDate: yesterday)

        viewModel.selectedDate = today
        viewModel.reload(using: repository)

        XCTAssertEqual(viewModel.historySections.count, 1)
        XCTAssertTrue(calendar.isDate(viewModel.historySections[0].id, inSameDayAs: yesterday))
        XCTAssertFalse(viewModel.historySections.contains { calendar.isDate($0.id, inSameDayAs: today) })
    }

    func testHistorySection_defaultExpandedOnlyForToday() throws {
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            XCTFail("Could not compute yesterday")
            return
        }

        _ = try repository.create(subject: subject, content: "今日任务", dueDate: today)
        _ = try repository.create(subject: subject, content: "昨日任务", dueDate: yesterday)

        viewModel.selectedDate = yesterday
        viewModel.reload(using: repository)

        XCTAssertFalse(viewModel.isHistoryExpanded(yesterday))
        XCTAssertTrue(viewModel.isHistoryExpanded(today))
    }

    func testToggleHistorySection() throws {
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            XCTFail("Could not compute yesterday")
            return
        }

        _ = try repository.create(subject: subject, content: "昨日任务", dueDate: yesterday)
        viewModel.selectedDate = today
        viewModel.reload(using: repository)

        XCTAssertFalse(viewModel.isHistoryExpanded(yesterday))
        viewModel.toggleHistorySection(yesterday)
        XCTAssertTrue(viewModel.isHistoryExpanded(yesterday))
        viewModel.toggleHistorySection(yesterday)
        XCTAssertFalse(viewModel.isHistoryExpanded(yesterday))
    }

    func testSetSelectedDate_filtersSelectedDayTasks() throws {
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            XCTFail("Could not compute tomorrow")
            return
        }

        _ = try repository.create(subject: subject, content: "今日任务", dueDate: today)
        _ = try repository.create(subject: subject, content: "明日任务", dueDate: tomorrow)

        viewModel.setSelectedDate(tomorrow, using: repository)

        XCTAssertEqual(viewModel.subjectGroups.count, 1)
        XCTAssertEqual(viewModel.subjectGroups[0].tasks.first?.content, "明日任务")
        XCTAssertTrue(viewModel.historySections.contains { calendar.isDate($0.id, inSameDayAs: today) })
    }

    func testDefaultHistoryExpanded_isTrueOnlyForToday() {
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            XCTFail("Could not compute yesterday")
            return
        }

        XCTAssertTrue(HomeQueryViewModel.defaultHistoryExpanded(calendar: calendar, date: today))
        XCTAssertFalse(HomeQueryViewModel.defaultHistoryExpanded(calendar: calendar, date: yesterday))
    }

    func testSortedHistoryDates_todayFirst() {
        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            XCTFail("Could not compute dates")
            return
        }

        let sorted = HomeQueryViewModel.sortedHistoryDates(
            [yesterday, tomorrow, today],
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(sorted.first, today)
    }
}
