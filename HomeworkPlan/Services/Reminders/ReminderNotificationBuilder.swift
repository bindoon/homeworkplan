import Foundation
import UserNotifications

struct ReminderNotificationBuilder {
    let settings: ReminderSettings
    let calendar: Calendar

    init(settings: ReminderSettings, calendar: Calendar = .current) {
        self.settings = settings
        self.calendar = calendar
    }

    func buildRequests(
        for task: HomeworkTask,
        ruleReminderTime: Date? = nil,
        now: Date = Date()
    ) -> [UNNotificationRequest] {
        guard !task.isCompleted else { return [] }

        let dueDay = calendar.startOfDay(for: task.dueDate)
        let isRecurring = task.sourceType == ImportSourceType.recurring.rawValue

        if isRecurring {
            return buildRecurringRequests(for: task, dueDay: dueDay, ruleReminderTime: ruleReminderTime, now: now)
        }

        return buildDueDateRequests(for: task, dueDay: dueDay, now: now)
    }

    private func buildDueDateRequests(
        for task: HomeworkTask,
        dueDay: Date,
        now: Date
    ) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        if let morningDate = settings.morningTime(on: dueDay, calendar: calendar), morningDate > now {
            requests.append(
                makeRequest(
                    identifier: ReminderNotificationID.morning(for: task.id),
                    task: task,
                    fireDate: morningDate,
                    bodySuffix: "早上提醒：今日截止"
                )
            )
        }

        if let afternoonDate = settings.afternoonTime(on: dueDay, calendar: calendar), afternoonDate > now {
            requests.append(
                makeRequest(
                    identifier: ReminderNotificationID.afternoon(for: task.id),
                    task: task,
                    fireDate: afternoonDate,
                    bodySuffix: "下午提醒：尚未完成"
                )
            )
        }

        return requests
    }

    private func buildRecurringRequests(
        for task: HomeworkTask,
        dueDay: Date,
        ruleReminderTime: Date?,
        now: Date
    ) -> [UNNotificationRequest] {
        guard let ruleReminderTime else { return [] }

        let hour = calendar.component(.hour, from: ruleReminderTime)
        let minute = calendar.component(.minute, from: ruleReminderTime)
        guard let fireDate = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: dueDay
        ) else {
            return []
        }

        guard fireDate > now else { return [] }

        return [
            makeRequest(
                identifier: ReminderNotificationID.recurring(for: task.id),
                task: task,
                fireDate: fireDate,
                bodySuffix: "重复作业提醒"
            )
        ]
    }

    private func makeRequest(
        identifier: String,
        task: HomeworkTask,
        fireDate: Date,
        bodySuffix: String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "作业提醒"
        let subjectPrefix = task.subject.map { "\($0.emoji) \($0.name) · " } ?? ""
        content.body = "\(subjectPrefix)\(task.content) — \(bodySuffix)"
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
