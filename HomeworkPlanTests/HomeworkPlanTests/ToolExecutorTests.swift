import SwiftData
import UIKit
import XCTest
@testable import HomeworkPlan

@MainActor
final class ToolExecutorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var taskRepository: TaskRepository!
    private var subjectRepository: SubjectRepository!
    private var recurringRuleRepository: RecurringRuleRepository!
    private var importRepository: ImportRepository!
    private var importService: ImportService!
    private var executor: ToolExecutor!
    private var subject: Subject!

    override func setUpWithError() throws {
        let schema = Schema([HomeworkTask.self, Subject.self, RecurringRule.self, ImportRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)

        taskRepository = TaskRepository(context: context)
        subjectRepository = SubjectRepository(context: context)
        recurringRuleRepository = RecurringRuleRepository(context: context)
        importRepository = ImportRepository(context: context)
        importService = ImportService(
            importRepository: importRepository,
            taskRepository: taskRepository,
            keychainService: KeychainService.shared
        )
        executor = ToolExecutor(
            taskRepository: taskRepository,
            subjectRepository: subjectRepository,
            recurringRuleRepository: recurringRuleRepository,
            importService: importService
        )

        subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        context.insert(subject)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        executor = nil
    }

    func testCreateTask_returnsProposalWithoutPersisting() async throws {
        let args = """
        {"content":"练字一页","subject_name":"语文","due_date":"2026-06-25"}
        """

        let result = try await executor.execute(toolName: "create_task", argumentsJSON: args)

        guard case .proposal(let proposal) = result else {
            return XCTFail("Expected proposal")
        }
        XCTAssertEqual(proposal.kind, .createTask)
        XCTAssertEqual(proposal.status, .pending)

        let descriptor = FetchDescriptor<HomeworkTask>()
        let count = try context.fetchCount(descriptor)
        XCTAssertEqual(count, 0, "Task should not be persisted before confirmation")
    }

    func testCreateTask_confirmPersistsTask() async throws {
        let args = """
        {"content":"练字一页","subject_name":"语文"}
        """
        let result = try await executor.execute(toolName: "create_task", argumentsJSON: args)
        guard case .proposal(let proposal) = result else {
            return XCTFail("Expected proposal")
        }

        let message = try executor.confirmProposal(proposal)
        XCTAssertFalse(message.isEmpty)

        let descriptor = FetchDescriptor<HomeworkTask>()
        let tasks = try context.fetch(descriptor)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.content, "练字一页")
    }

    func testListTasks_returnsImmediateResult() async throws {
        _ = try taskRepository.create(subject: subject, content: "阅读", dueDate: Date())

        let result = try await executor.execute(toolName: "list_tasks", argumentsJSON: "{\"days_ahead\":7}")

        guard case .immediate(let json) = result else {
            return XCTFail("Expected immediate result")
        }
        XCTAssertTrue(json.contains("阅读"))
        XCTAssertTrue(json.contains("tasks"))
    }

    func testListSubjects_returnsSubjects() async throws {
        let result = try await executor.execute(toolName: "list_subjects", argumentsJSON: "{}")

        guard case .immediate(let json) = result else {
            return XCTFail("Expected immediate result")
        }
        XCTAssertTrue(json.contains("语文"))
    }

    func testImportFromImage_requiresAttachment() async throws {
        let args = """
        {"ocr_text":"数学 P10 明天交"}
        """

        do {
            _ = try await executor.execute(toolName: "import_from_image", argumentsJSON: args)
            XCTFail("Expected missing attachment error")
        } catch let error as ToolExecutorError {
            XCTAssertTrue(error.localizedDescription.contains("截图附件"))
        }
    }

    func testImportFromImage_rejectsEmptyOCRText() async throws {
        let image = UIImage(systemName: "doc.text")!
        let attachment = UserMessageAttachment(image: image, ocrText: "   ")

        do {
            _ = try await executor.execute(
                toolName: "import_from_image",
                argumentsJSON: "{\"ocr_text\":\"   \"}",
                attachment: attachment
            )
            XCTFail("Expected invalid ocr_text")
        } catch let error as ToolExecutorError {
            XCTAssertTrue(error.localizedDescription.contains("ocr_text"))
        }
    }

    func testCreateSubject_returnsProposalWithoutPersisting() async throws {
        let args = """
        {"name":"科学","emoji":"🔬"}
        """

        let result = try await executor.execute(toolName: "create_subject", argumentsJSON: args)

        guard case .proposal(let proposal) = result else {
            return XCTFail("Expected proposal")
        }
        XCTAssertEqual(proposal.kind, .createSubject)
        XCTAssertEqual(proposal.status, .pending)

        let descriptor = FetchDescriptor<Subject>()
        let count = try context.fetchCount(descriptor)
        XCTAssertEqual(count, 1, "Only setup subject should exist before confirmation")
    }

    func testCreateSubject_confirmPersistsSubject() async throws {
        let args = """
        {"name":"科学","emoji":"🔬"}
        """
        let result = try await executor.execute(toolName: "create_subject", argumentsJSON: args)
        guard case .proposal(let proposal) = result else {
            return XCTFail("Expected proposal")
        }

        let message = try executor.confirmProposal(proposal)
        XCTAssertTrue(message.contains("科学"))

        let subjects = try subjectRepository.fetchAll()
        XCTAssertTrue(subjects.contains { $0.name == "科学" && $0.emoji == "🔬" })
    }

    func testCreateRecurringRule_returnsProposalWithoutPersisting() async throws {
        let args = """
        {"content":"练字","subject_name":"语文","frequency":"daily"}
        """

        let result = try await executor.execute(toolName: "create_recurring_rule", argumentsJSON: args)

        guard case .proposal(let proposal) = result else {
            return XCTFail("Expected proposal")
        }
        XCTAssertEqual(proposal.kind, .createRecurringRule)
        XCTAssertEqual(proposal.status, .pending)

        let descriptor = FetchDescriptor<RecurringRule>()
        let count = try context.fetchCount(descriptor)
        XCTAssertEqual(count, 0, "Rule should not be persisted before confirmation")
    }

    func testCreateRecurringRule_confirmPersistsRule() async throws {
        let args = """
        {"content":"练字","subject_name":"语文","frequency":"daily"}
        """
        let result = try await executor.execute(toolName: "create_recurring_rule", argumentsJSON: args)
        guard case .proposal(let proposal) = result else {
            return XCTFail("Expected proposal")
        }

        let message = try executor.confirmProposal(proposal)
        XCTAssertTrue(message.contains("练字"))

        let rules = try recurringRuleRepository.fetchAll()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.content, "练字")
        XCTAssertEqual(rules.first?.frequency, .daily)
        XCTAssertEqual(rules.first?.subject?.name, "语文")
    }
}
