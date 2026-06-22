import XCTest
@testable import HomeworkPlan

final class ImportContextBuilderTests: XCTestCase {
    func testBuild_mapsHomeworkTaskFields() {
        let subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        let dueDate = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 23))!
        let task = HomeworkTask(
            subject: subject,
            content: "抄课文",
            dueDate: dueDate,
            sourceType: ImportSourceType.manual.rawValue
        )

        let items = ImportContextBuilder.build(from: [task])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, task.id.uuidString)
        XCTAssertEqual(items[0].subject, "语文")
        XCTAssertEqual(items[0].content, "抄课文")
        XCTAssertEqual(items[0].dueDate, "2026-06-23")
        XCTAssertFalse(items[0].isCompleted)
    }

    func testEncodeForPrompt_returnsJSONArray() {
        let items = [
            ExistingTaskContextItem(
                id: "task-1",
                subject: "数学",
                content: "练习册 P12",
                dueDate: "2026-06-24",
                isCompleted: false
            )
        ]

        let json = ImportContextBuilder.encodeForPrompt(items)
        XCTAssertTrue(json.contains("\"id\":\"task-1\""))
        XCTAssertTrue(json.contains("\"subject\":\"数学\""))
    }

    func testEncodeForPrompt_emptyReturnsEmptyArray() {
        XCTAssertEqual(ImportContextBuilder.encodeForPrompt([]), "[]")
    }
}
