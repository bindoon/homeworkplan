import XCTest
@testable import HomeworkPlan

final class DueDateResolverTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar = cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testResolve_noDateInSource_defaultsToToday() {
        let importedAt = date(2026, 6, 22)
        let candidate = TaskCandidate(
            subjectName: "语文",
            content: "抄课文第三段",
            dueDate: date(2026, 6, 23),
            notes: "明天交"
        )

        let resolved = DueDateResolver.resolve(
            for: candidate,
            importedAt: importedAt,
            rawText: "抄课文第三段",
            calendar: calendar
        )

        XCTAssertEqual(resolved, importedAt)
    }

    func testResolve_aiNotesWithTomorrow_ignoredWithoutSourceMention() {
        let importedAt = date(2026, 6, 22)
        let candidate = TaskCandidate(
            subjectName: "数学",
            content: "练习册 P12",
            dueDate: date(2026, 6, 23),
            notes: "明天交"
        )

        let resolved = DueDateResolver.resolve(
            for: candidate,
            importedAt: importedAt,
            rawText: "练习册 P12",
            calendar: calendar
        )

        XCTAssertEqual(resolved, importedAt)
    }

    func testResolve_sourceSaysTomorrow_usesTomorrow() {
        let importedAt = date(2026, 6, 22)
        let candidate = TaskCandidate(
            subjectName: "语文",
            content: "背诵古诗，明天交",
            dueDate: date(2026, 6, 23)
        )

        let resolved = DueDateResolver.resolve(
            for: candidate,
            importedAt: importedAt,
            rawText: "背诵古诗，明天交",
            calendar: calendar
        )

        XCTAssertEqual(resolved, date(2026, 6, 23))
    }

    func testResolve_explicitDateInSource_usesCandidateDueDate() {
        let importedAt = date(2026, 6, 22)
        let candidate = TaskCandidate(
            subjectName: "英语",
            content: "6月25日完成练习",
            dueDate: date(2026, 6, 25)
        )

        let resolved = DueDateResolver.resolve(
            for: candidate,
            importedAt: importedAt,
            rawText: "6月25日完成练习",
            calendar: calendar
        )

        XCTAssertEqual(resolved, date(2026, 6, 25))
    }

    func testParseLocalDateString_avoidsTimezoneShift() {
        let parsed = TaskCandidate.parseLocalDateString("2026-06-22", calendar: calendar)
        XCTAssertEqual(parsed, date(2026, 6, 22))
    }

    func testDecodeDueDate_parsesDateOnlyString() throws {
        let json = """
        {"tasks":[{"subject":"语文","content":"抄课文","dueDate":"2026-06-22","confidence":0.9}],"message":null}
        """
        let response = try ParseService.decodeResponseContent(json)
        XCTAssertEqual(response.tasks.first?.dueDate, date(2026, 6, 22))
    }
}
