import Foundation

struct CalendarRecurringCandidate: Identifiable, Hashable {
    let id: String
    let title: String
    let calendarName: String
    let schedule: RecurringRuleSchedule
    let reminderTime: Date
    let isDuplicate: Bool

    var frequencySummary: String {
        schedule.summary()
    }
}

enum DingTalkCalendarImportError: LocalizedError {
    case calendarAccessDenied
    case noCalendarsFound
    case noRecurringEventsFound
    case invalidICSFile
    case unsupportedRecurrence

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            return "需要日历访问权限才能读取钉钉同步的日程"
        case .noCalendarsFound:
            return "未找到可用日历，请先在 iPhone 设置中同步钉钉日历"
        case .noRecurringEventsFound:
            return "所选日历中没有可导入的重复日程"
        case .invalidICSFile:
            return "无法解析日历文件，请确认是有效的 .ics 文件"
        case .unsupportedRecurrence:
            return "该日程的重复规则暂不支持导入"
        }
    }
}
