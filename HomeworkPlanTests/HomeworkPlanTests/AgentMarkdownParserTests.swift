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
        XCTAssertTrue(attributed?.characters.isEmpty == false)
    }

    func testReturnsPartialForIncompleteStreamingChunk() {
        let partial = "**未完成"
        let attributed = AgentMarkdownParser.attributedString(from: partial)
        XCTAssertNotNil(attributed)
    }

    func testPreprocessConvertsPlainSingleNewlinesToHardBreaks() {
        let result = AgentMarkdownParser.preprocessLineBreaks(in: "第一行\n第二行")
        XCTAssertEqual(result, "第一行  \n第二行")
    }

    func testPreprocessPreservesParagraphBreaks() {
        let result = AgentMarkdownParser.preprocessLineBreaks(in: "段落一\n\n段落二")
        XCTAssertEqual(result, "段落一\n\n段落二")
    }

    func testPreprocessPreservesCodeBlockNewlines() {
        let markdown = """
        ```swift
        let a = 1
        let b = 2
        ```
        """
        let result = AgentMarkdownParser.preprocessLineBreaks(in: markdown)
        XCTAssertEqual(result, markdown)
    }

    func testPreprocessPreservesListItemNewlines() {
        let markdown = "- 数学\n- 英语"
        let result = AgentMarkdownParser.preprocessLineBreaks(in: markdown)
        XCTAssertEqual(result, markdown)
    }

    func testPlainLinesRenderOnSeparateLines() {
        let markdown = "第一行\n第二行"
        let attributed = AgentMarkdownParser.attributedString(from: markdown)
        XCTAssertNotNil(attributed)
        let rendered = String(attributed!.characters)
        XCTAssertTrue(rendered.contains("第一行"))
        XCTAssertTrue(rendered.contains("第二行"))
        XCTAssertTrue(rendered.contains("\n"))
    }
}
