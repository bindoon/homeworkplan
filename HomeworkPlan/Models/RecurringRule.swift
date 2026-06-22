import Foundation
import SwiftData

enum RecurringFrequency: String, CaseIterable, Identifiable {
    case daily
    case weekdays
    case weekly
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:
            return "每天"
        case .weekdays:
            return "工作日"
        case .weekly:
            return "每周"
        case .custom:
            return "自定义"
        }
    }
}

@Model
final class RecurringRule {
    var id: UUID = UUID()
    var subject: Subject?
    var content: String = ""
    var frequencyRaw: String = RecurringFrequency.daily.rawValue
    var weeklyWeekday: Int = 2
    var customWeekdaysMask: Int = 0
    var reminderTime: Date = Date()
    var isEnabled: Bool = true
    var lastGeneratedDate: Date? = nil
    var createdAt: Date = Date()

    init() {}

    init(
        subject: Subject?,
        content: String,
        frequency: RecurringFrequency,
        weeklyWeekday: Int = 2,
        customWeekdaysMask: Int = 0,
        reminderTime: Date = Date(),
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.subject = subject
        self.content = content
        self.frequencyRaw = frequency.rawValue
        self.weeklyWeekday = weeklyWeekday
        self.customWeekdaysMask = customWeekdaysMask
        self.reminderTime = reminderTime
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    func shouldGenerate(on date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)

        switch frequency {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekly:
            return weekday == weeklyWeekday
        case .custom:
            guard customWeekdaysMask != 0 else { return false }
            return (customWeekdaysMask & (1 << weekday)) != 0
        }
    }
}

enum RecurringRuleError: LocalizedError {
    case emptyContent
    case notFound
    case invalidCustomWeekdays

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "作业内容不能为空"
        case .notFound:
            return "重复规则不存在"
        case .invalidCustomWeekdays:
            return "请至少选择一个重复日期"
        }
    }
}

extension RecurringRule {
    static func weekdayDisplayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        case 7: return "周六"
        default: return "未知"
        }
    }

    static func frequencySummary(
        frequency: RecurringFrequency,
        weeklyWeekday: Int,
        customWeekdaysMask: Int
    ) -> String {
        switch frequency {
        case .daily:
            return "每天"
        case .weekdays:
            return "工作日"
        case .weekly:
            return "每周\(weekdayDisplayName(weeklyWeekday))"
        case .custom:
            let days = (1...7).filter { (customWeekdaysMask & (1 << $0)) != 0 }
            let names = days.map { weekdayDisplayName($0) }
            return names.isEmpty ? "自定义" : names.joined(separator: "、")
        }
    }
}
