import SwiftData
import XCTest
@testable import HomeworkPlan

@MainActor
final class ImportRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repository: ImportRepository!

    override func setUpWithError() throws {
        let schema = Schema([ImportRecord.self, HomeworkTask.self, Subject.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        repository = ImportRepository(context: context)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        repository = nil
    }

    func testFindByContentHash_returnsExistingRecord() throws {
        let hash = ContentHashService.sha256("重复内容")
        _ = try repository.createRecord(
            contentHash: hash,
            rawText: "重复内容",
            sourceType: .pasted
        )

        let found = try repository.findByContentHash(hash)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.rawText, "重复内容")
    }

    func testLinkTask_appendsTaskID() throws {
        let record = try repository.createRecord(
            contentHash: "abc",
            rawText: "text",
            sourceType: .screenshot
        )
        let taskID = UUID()
        try repository.linkTask(recordID: record.id, taskID: taskID)

        let fetched = try repository.fetchRecord(id: record.id)
        XCTAssertTrue(fetched?.linkedTaskIDList.contains(taskID) == true)
    }
}
