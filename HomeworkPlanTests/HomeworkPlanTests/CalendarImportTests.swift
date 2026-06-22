import XCTest
@testable import HomeworkPlan

final class CalendarRecurrenceMapperTests: XCTestCase {
    func testMapRRULE_daily() {
        let schedule = CalendarRecurrenceMapper.map(rrule: "FREQ=DAILY")
        XCTAssertEqual(schedule?.frequency, .daily)
    }

    func testMapRRULE_weekdays() {
        let schedule = CalendarRecurrenceMapper.map(rrule: "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR")
        XCTAssertEqual(schedule?.frequency, .weekdays)
    }

    func testMapRRULE_weeklySingleDay() {
        let schedule = CalendarRecurrenceMapper.map(rrule: "FREQ=WEEKLY;BYDAY=MO")
        XCTAssertEqual(schedule?.frequency, .weekly)
        XCTAssertEqual(schedule?.weeklyWeekday, 2)
    }

    func testMapRRULE_customWeekdays() {
        let schedule = CalendarRecurrenceMapper.map(rrule: "FREQ=WEEKLY;BYDAY=MO,WE,FR")
        XCTAssertEqual(schedule?.frequency, .custom)
        XCTAssertEqual(schedule?.customWeekdaysMask, (1 << 2) | (1 << 4) | (1 << 6))
    }

    func testReminderTime_usesHourAndMinute() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let source = calendar.date(from: DateComponents(hour: 7, minute: 30))!
        let reminder = CalendarRecurrenceMapper.reminderTime(from: source, calendar: calendar)

        XCTAssertEqual(calendar.component(.hour, from: reminder), 7)
        XCTAssertEqual(calendar.component(.minute, from: reminder), 30)
    }
}

final class ICSRecurringParserTests: XCTestCase {
    func testParseEvents_extractsRecurringEvent() throws {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:test-event-1
        SUMMARY:每日练字
        DTSTART:20260622T183000
        RRULE:FREQ=DAILY
        END:VEVENT
        END:VCALENDAR
        """

        let events = ICSRecurringParser.parseEvents(from: ics)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].summary, "每日练字")
        XCTAssertEqual(events[0].rrule, "FREQ=DAILY")
        XCTAssertNotNil(events[0].startDate)
    }

    func testParseEvents_skipsNonRecurringEvents() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:one-off
        SUMMARY:家长会
        DTSTART:20260622T090000
        END:VEVENT
        END:VCALENDAR
        """

        let events = ICSRecurringParser.parseEvents(from: ics)
        XCTAssertTrue(events.isEmpty)
    }

    func testParseEvents_unfoldsWrappedLines() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:wrapped
        SUMMARY:每天阅
         读英语
        DTSTART:20260622T200000
        RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR
        END:VEVENT
        END:VCALENDAR
        """

        let events = ICSRecurringParser.parseEvents(from: ics)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].summary, "每天阅读英语")
    }
}

@MainActor
final class DingTalkCalendarImportServiceTests: XCTestCase {
    func testIsLikelyDingTalkCalendar_matchesChineseName() {
        XCTAssertTrue(DingTalkCalendarImportService.isLikelyDingTalkCalendar("钉钉日历"))
    }

    func testIsLikelyDingTalkCalendar_matchesEnglishName() {
        XCTAssertTrue(DingTalkCalendarImportService.isLikelyDingTalkCalendar("DingTalk"))
    }

    func testResolveSubject_matchesChineseKeyword() {
        let subject = Subject(name: "语文", emoji: "📖", sortOrder: 0, isDefault: true)
        let resolved = DingTalkCalendarImportService.resolveSubject(for: "语文每日阅读", in: [subject])
        XCTAssertEqual(resolved?.name, "语文")
    }

    func testLoadCandidatesFromICSData() throws {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:ics-1
        SUMMARY:每日练字
        DTSTART:20260622T183000
        RRULE:FREQ=DAILY
        END:VEVENT
        END:VCALENDAR
        """.data(using: .utf8)!

        let service = DingTalkCalendarImportService()
        let candidates = try service.loadCandidates(fromICSData: ics, existingRules: [])

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].title, "每日练字")
        XCTAssertEqual(candidates[0].schedule.frequency, .daily)
        XCTAssertFalse(candidates[0].isDuplicate)
    }
}
