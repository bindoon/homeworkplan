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

    func testDecodeResponseContent_parsesActionFields() throws {
        let json = """
        {"tasks":[{"subject":"语文","content":"抄课文","dueDate":"2026-06-23","action":"update","matchedTaskId":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","confidence":0.9}],"message":null}
        """
        let response = try ParseService.decodeResponseContent(json)
        XCTAssertEqual(response.tasks.count, 1)
        XCTAssertEqual(response.tasks.first?.action, .update)
        XCTAssertEqual(
            response.tasks.first?.matchedTaskId?.uuidString,
            "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        )
    }

    func testDecodeResponseContent_defaultsActionToCreate() throws {
        let json = """
        {"tasks":[{"subject":"语文","content":"抄课文","confidence":0.9}],"message":null}
        """
        let response = try ParseService.decodeResponseContent(json)
        XCTAssertEqual(response.tasks.first?.action, .create)
        XCTAssertNil(response.tasks.first?.matchedTaskId)
    }

    func testDecodeResponseContent_throwsOnInvalidJSON() {
        XCTAssertThrowsError(try ParseService.decodeResponseContent("not json"))
    }
}
