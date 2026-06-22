import XCTest
@testable import HomeworkPlan

final class ReminderNotificationBuilderTests: XCTestCase {
    private var settings: ReminderSettings!
    private var calendar: Calendar!
    private var builder: ReminderNotificationBuilder!

    override func setUp() {
        super.setUp()
        let suiteName = "ReminderNotificationBuilderTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        settings = ReminderSettings(defaults: defaults)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        builder = ReminderNotificationBuilder(settings: settings, calendar: calendar)
    }

    func testDefaultTimes_areEightAMAndFivePM() {
        XCTAssertEqual(settings.morningHour, 8)
        XCTAssertEqual(settings.morningMinute, 0)
        XCTAssertEqual(settings.afternoonHour, 17)
        XCTAssertEqual(settings.afternoonMinute, 0)
    }

    func testBuilder_dueDateTask_morningAndAfternoon() throws {
        let dueDay = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 25,
            hour: 0,
            minute: 0
        )))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 20
        )))

        let task = HomeworkTask()
        task.id = UUID()
        task.content = "数学作业"
        task.dueDate = dueDay
        task.sourceType = ImportSourceType.manual.rawValue

        let requests = builder.buildRequests(for: task, now: now)
        let ids = Set(requests.map(\.identifier))

        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(ids.contains(ReminderNotificationID.morning(for: task.id)))
        XCTAssertTrue(ids.contains(ReminderNotificationID.afternoon(for: task.id)))
    }

    func testBuilder_recurringTask_singleNotificationAtRuleTime() throws {
        let dueDay = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 25
        )))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 20
        )))
        let ruleReminder = try XCTUnwrap(calendar.date(
            bySettingHour: 18,
            minute: 30,
            second: 0,
            of: dueDay
        ))

        let task = HomeworkTask()
        task.id = UUID()
        task.content = "每日练字"
        task.dueDate = dueDay
        task.sourceType = ImportSourceType.recurring.rawValue

        let requests = builder.buildRequests(for: task, ruleReminderTime: ruleReminder, now: now)

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.identifier, ReminderNotificationID.recurring(for: task.id))
    }
}
