import XCTest
@testable import HomeworkPlan

final class AgentMarkdownParserTests: XCTestCase {
    func testParsesBoldAndList() {
        let markdown = """
        **今日待办**
        - 数学：P10
        - 英语：抄写
        """

        let attributed = AgentMarkdownParser.attributedString(from: markdown)
        XCTAssertNotNil(attributed)
        let rendered = String(attributed!.characters)
        XCTAssertTrue(rendered.contains("今日待办"))
        XCTAssertTrue(rendered.contains("- 数学：P10"))
        XCTAssertTrue(rendered.contains("- 英语：抄写"))
        XCTAssertTrue(rendered.contains("\n"))
    }

    func testReturnsPartialForIncompleteStreamingChunk() {
        let partial = "**未完成"
        let attributed = AgentMarkdownParser.attributedString(from: partial)
        XCTAssertNotNil(attributed)
    }

    func testPreservesSingleLineBreaks() {
        let markdown = "第一行\n第二行"
        let attributed = AgentMarkdownParser.attributedString(from: markdown)
        XCTAssertNotNil(attributed)
        XCTAssertEqual(String(attributed!.characters), "第一行\n第二行")
    }

    func testPreservesParagraphBreaks() {
        let markdown = "段落一\n\n段落二"
        let attributed = AgentMarkdownParser.attributedString(from: markdown)
        XCTAssertNotNil(attributed)
        XCTAssertEqual(String(attributed!.characters), "段落一\n\n段落二")
    }

    func testPreservesListLineBreaks() {
        let markdown = "- 数学\n- 英语"
        let attributed = AgentMarkdownParser.attributedString(from: markdown)
        XCTAssertNotNil(attributed)
        XCTAssertEqual(String(attributed!.characters), "- 数学\n- 英语")
    }

    func testNormalizesWindowsLineEndings() {
        let markdown = "第一行\r\n第二行"
        let attributed = AgentMarkdownParser.attributedString(from: markdown)
        XCTAssertNotNil(attributed)
        XCTAssertEqual(String(attributed!.characters), "第一行\n第二行")
    }
}
