import UserNotifications
import XCTest
@testable import HomeworkPlan

final class NotificationBudgetManagerTests: XCTestCase {
    private var manager: NotificationBudgetManager!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        manager = NotificationBudgetManager()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testBudgetManager_limitsTo64() {
        let today = calendar.startOfDay(for: Date())
        let requests = (0..<80).map { index in
            makeRequest(
                id: "id-\(index)",
                fireDate: calendar.date(byAdding: .day, value: index + 1, to: today)!,
                hour: 8,
                calendar: calendar
            )
        }

        let selected = manager.selectRequests(requests)
        XCTAssertEqual(selected.count, 64)
        XCTAssertEqual(selected.first?.identifier, "id-0")
        XCTAssertEqual(selected.last?.identifier, "id-63")
    }

    private func makeRequest(
        id: String,
        fireDate: Date,
        hour: Int,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Test"
        let withHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: fireDate)!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: withHour)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}
