import XCTest
@testable import HomeworkPlan

final class ParseServiceTests: XCTestCase {
    func testDecodeResponseContent_parsesTaskArrayWrapper() throws {
        let json = """
        {"tasks":[{"subject":"语文","content":"抄课文","dueDate":"2026-06-23","assigner":"王老师","confidence":0.9,"notes":null}],"message":null}
        """
        let response = try ParseService.decodeResponseContent(json)
        XCTAssertEqual(response.tasks.count, 1)
        XCTAssertEqual(response.tasks.first?.subjectName, "语文")
        XCTAssertEqual(response.tasks.first?.content, "抄课文")
    }

    func testDecodeResponseContent_parsesBareArray() throws {
        let json = """
        [{"subject":"数学","content":"练习册P12","confidence":0.85}]
        """
        let response = try ParseService.decodeResponseContent(json)
        XCTAssertEqual(response.tasks.count, 1)
        XCTAssertEqual(response.tasks.first?.subjectName, "数学")
    }

    func testDecodeResponseContent_throwsOnInvalidJSON() {
        XCTAssertThrowsError(try ParseService.decodeResponseContent("not json"))
    }
}
