import SwiftData
import XCTest
@testable import HomeworkPlan

@MainActor
final class SubjectDedupeServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([HomeworkTask.self, Subject.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testMergeDuplicates_mergesSameNormalizedName() throws {
        let first = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        let duplicate = Subject(name: " 语文 ", emoji: "📖", sortOrder: 5, isDefault: false)
        context.insert(first)
        context.insert(duplicate)

        let task = HomeworkTask(subject: duplicate, content: "作业", dueDate: Date())
        context.insert(task)
        try context.save()

        try SubjectDedupeService.mergeDuplicates(context: context)

        let subjects = try context.fetch(FetchDescriptor<Subject>())
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(task.subject?.id, subjects.first?.id)
    }
}
