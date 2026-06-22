import XCTest
@testable import HomeworkPlan

final class ToolRegistryTests: XCTestCase {
    func testAllToolsRegistered() {
        let names = Set(ToolRegistry.allDefinitions.map(\.name))
        let expected = Set(AgentToolName.allCases.map(\.rawValue))
        XCTAssertEqual(names, expected)
        XCTAssertEqual(ToolRegistry.allDefinitions.count, AgentToolName.allCases.count)
    }

    func testSchemasAreValidJSON() throws {
        for definition in ToolRegistry.allDefinitions {
            let schema = definition.openAISchema()
            let data = try JSONSerialization.data(withJSONObject: schema)
            XCTAssertFalse(data.isEmpty)

            let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(decoded)
            XCTAssertEqual(decoded?["type"] as? String, "function")

            let function = decoded?["function"] as? [String: Any]
            XCTAssertNotNil(function)
            XCTAssertEqual(function?["name"] as? String, definition.name)
            XCTAssertFalse((function?["description"] as? String ?? "").isEmpty)

            let parameters = function?["parameters"] as? [String: Any]
            XCTAssertNotNil(parameters)
            XCTAssertEqual(parameters?["type"] as? String, "object")
        }
    }

    func testMutatingFlags() {
        XCTAssertFalse(ToolRegistry.isMutating(name: "list_tasks"))
        XCTAssertFalse(ToolRegistry.isMutating(name: "list_subjects"))
        XCTAssertFalse(ToolRegistry.isMutating(name: "list_recurring_rules"))
        XCTAssertTrue(ToolRegistry.isMutating(name: "create_task"))
        XCTAssertTrue(ToolRegistry.isMutating(name: "import_from_text"))
        XCTAssertTrue(ToolRegistry.isMutating(name: "delete_task"))
    }
}
