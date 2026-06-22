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
            sortKey(for: lhs) < sortKey(for: rhs)
        }
        return Array(sorted.prefix(limit))
    }

    private func triggerDate(for request: UNNotificationRequest) -> Date? {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return nil
        }
        let date = trigger.nextTriggerDate()
            ?? Calendar.current.date(from: trigger.dateComponents)
        guard let date else { return nil }
        // Expired one-shot notifications should not consume pending budget.
        if date < Date() { return nil }
        return date
    }

    private func sortKey(for request: UNNotificationRequest) -> Date {
        triggerDate(for: request) ?? .distantFuture
    }
}
