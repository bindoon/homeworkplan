import XCTest
@testable import HomeworkPlan

final class ContentHashServiceTests: XCTestCase {
    func testSha256_sameTextSameHash() {
        let hash1 = ContentHashService.sha256("语文：抄课文第三段")
        let hash2 = ContentHashService.sha256("语文：抄课文第三段")
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash1.count, 64)
    }

    func testSha256_differentTextDifferentHash() {
        let hash1 = ContentHashService.sha256("语文作业")
        let hash2 = ContentHashService.sha256("数学作业")
        XCTAssertNotEqual(hash1, hash2)
    }

    func testSha256_trimsWhitespace() {
        let hash1 = ContentHashService.sha256("  作业内容  ")
        let hash2 = ContentHashService.sha256("作业内容")
        XCTAssertEqual(hash1, hash2)
    }
}
