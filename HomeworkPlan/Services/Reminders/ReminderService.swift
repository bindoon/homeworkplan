import Foundation
import UserNotifications

@MainActor
final class ReminderService {
    static let rescheduleHorizonDays = 14

    private let notificationCenter: UNUserNotificationCenter
    private let settings: ReminderSettings
    private let budgetManager: NotificationBudgetManager
    private let builder: ReminderNotificationBuilder
    private let calendar: Calendar

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        settings: ReminderSettings = ReminderSettings(),
        budgetManager: NotificationBudgetManager = NotificationBudgetManager(),
        calendar: Calendar = .current
    ) {
        self.notificationCenter = notificationCenter
        self.settings = settings
        self.budgetManager = budgetManager
        self.calendar = calendar
        self.builder = ReminderNotificationBuilder(settings: settings, calendar: calendar)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func schedule(for task: HomeworkTask, ruleReminderTime: Date? = nil) async {
        guard await requestAuthorizationIfNeeded() else { return }

        let requests = builder.buildRequests(for: task, ruleReminderTime: ruleReminderTime)
        guard !requests.isEmpty else { return }

        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ReminderNotificationID.all(for: task.id)
        )

        for request in requests {
            try? await notificationCenter.add(request)
        }
    }

    func cancel(for taskId: UUID) async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ReminderNotificationID.all(for: taskId)
        )
    }

    func rescheduleAll(
        using taskRepository: TaskRepository,
        ruleRepository: RecurringRuleRepository
    ) async {
        guard await requestAuthorizationIfNeeded() else { return }

        do {
            let tasks = try taskRepository.fetchIncompleteTasks(
                dueWithinDays: Self.rescheduleHorizonDays,
                calendar: calendar
            )

            var desired: [UNNotificationRequest] = []
            let now = Date()

            for task in tasks {
                let ruleTime: Date?
                if task.sourceType == ImportSourceType.recurring.rawValue,
                   let ruleId = task.recurringRuleId {
                    ruleTime = try ruleRepository.fetch(id: ruleId)?.reminderTime
                } else {
                    ruleTime = nil
                }
                desired.append(
                    contentsOf: builder.buildRequests(for: task, ruleReminderTime: ruleTime, now: now)
                )
            }

            let selected = budgetManager.selectRequests(desired)
            let desiredIDs = Set(selected.map(\.identifier))

            let pending = await notificationCenter.pendingNotificationRequests()
            let pendingIDs = Set(pending.map(\.identifier))
            let staleIDs = pendingIDs.subtracting(desiredIDs)

            if !staleIDs.isEmpty {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(staleIDs))
            }

            for request in selected where !pendingIDs.contains(request.identifier) {
                try? await notificationCenter.add(request)
            }
        } catch {
            print("Reminder reschedule failed: \(error)")
        }
    }
}
