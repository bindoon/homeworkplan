import Foundation
import UserNotifications

/// Selects pending notifications within iOS's 64-request limit, prioritizing nearest fire dates.
struct NotificationBudgetManager {
    static let maxPending = 64

    func selectRequests(
        _ requests: [UNNotificationRequest],
        limit: Int = NotificationBudgetManager.maxPending
    ) -> [UNNotificationRequest] {
        guard requests.count > limit else { return requests }

        let sorted = requests.sorted { lhs, rhs in
            let leftDate = triggerDate(for: lhs) ?? .distantFuture
            let rightDate = triggerDate(for: rhs) ?? .distantFuture
            return leftDate < rightDate
        }
        return Array(sorted.prefix(limit))
    }

    private func triggerDate(for request: UNNotificationRequest) -> Date? {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return nil
        }
        return trigger.nextTriggerDate()
    }
}
