import SwiftData
import XCTest
@testable import HomeworkPlan

@MainActor
final class ImportReviewViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var taskRepository: TaskRepository!
    private var importRepository: ImportRepository!
    private var subjectRepository: SubjectRepository!
    private var viewModel: ImportReviewViewModel!
    private var subject: Subject!

    override func setUpWithError() throws {
        let schema = Schema([HomeworkTask.self, Subject.self, ImportRecord.self, RecurringRule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        taskRepository = TaskRepository(context: context)
        importRepository = ImportRepository(context: context)
        subjectRepository = SubjectRepository(context: context)
        viewModel = ImportReviewViewModel(
            taskRepository: taskRepository,
            importRepository: importRepository,
            subjectRepository: subjectRepository
        )

        subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        context.insert(subject)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testLoad_skipCandidateIsAutoDiscarded() {
        let candidate = TaskCandidate(
            subjectName: "语文",
            content: "抄课文",
            action: .skip
        )
        let result = ImportResult(
            importRecord: nil,
            candidates: [candidate],
            rawText: "抄课文",
            isDuplicate: false,
            parseFailed: false,
            message: nil,
            sourceType: .pasted,
            sourceImagePath: ""
        )

        viewModel.load(from: result, subjects: [subject])

        XCTAssertEqual(viewModel.candidates.count, 1)
        XCTAssertEqual(viewModel.candidates[0].resolvedAction, .skip)
        XCTAssertEqual(viewModel.candidates[0].status, .discarded)
        XCTAssertTrue(viewModel.pendingCandidates.isEmpty)
    }

    func testConfirm_updateExistingTask() throws {
        let existing = try taskRepository.create(
            subject: subject,
            content: "抄课文",
            dueDate: Date(),
            sourceType: ImportSourceType.manual.rawValue
        )

        let candidate = TaskCandidate(
            subjectName: "语文",
            content: "抄课文第三段",
            action: .update,
            matchedTaskId: existing.id
        )
        let result = ImportResult(
            importRecord: nil,
            candidates: [candidate],
            rawText: "抄课文第三段",
            isDuplicate: false,
            parseFailed: false,
            message: nil,
            sourceType: .pasted,
            sourceImagePath: ""
        )

        viewModel.load(from: result, subjects: [subject])
        let reviewItem = try XCTUnwrap(viewModel.pendingCandidates.first)
        XCTAssertEqual(reviewItem.resolvedAction, .update)
        XCTAssertNotNil(reviewItem.matchedTaskPreview)

        try viewModel.confirm(reviewItem.id)

        let updated = try XCTUnwrap(taskRepository.fetchTask(id: existing.id))
        XCTAssertEqual(updated.content, "抄课文第三段")
    }

    func testConfirm_invalidUpdateFallsBackToCreate() throws {
        let candidate = TaskCandidate(
            subjectName: "语文",
            content: "新作业",
            action: .update,
            matchedTaskId: UUID()
        )
        let result = ImportResult(
            importRecord: nil,
            candidates: [candidate],
            rawText: "新作业",
            isDuplicate: false,
            parseFailed: false,
            message: nil,
            sourceType: .pasted,
            sourceImagePath: ""
        )

        viewModel.load(from: result, subjects: [subject])
        let reviewItem = try XCTUnwrap(viewModel.pendingCandidates.first)
        XCTAssertEqual(reviewItem.resolvedAction, .create)

        try viewModel.confirm(reviewItem.id)

        let tasks = try taskRepository.fetchRecentForImportContext()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].content, "新作业")
    }
}

@MainActor
final class TaskRepositoryImportContextTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var taskRepository: TaskRepository!

    override func setUpWithError() throws {
        let schema = Schema([HomeworkTask.self, Subject.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        taskRepository = TaskRepository(context: context)
    }

    func testFetchRecentForImportContext_returnsTasksWithinWindow() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let oldDate = calendar.date(byAdding: .day, value: -30, to: today)!

        _ = try taskRepository.create(subject: nil, content: "今天", dueDate: today)
        _ = try taskRepository.create(subject: nil, content: "明天", dueDate: tomorrow)
        _ = try taskRepository.create(subject: nil, content: "过期", dueDate: oldDate)

        let recent = try taskRepository.fetchRecentForImportContext(from: today)

        XCTAssertEqual(recent.map(\.content).sorted(), ["今天", "明天"])
    }
}
