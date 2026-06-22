import EventKit
import Foundation

enum CalendarRecurrenceMapper {
    static func map(ekRule: EKRecurrenceRule) -> RecurringRuleSchedule? {
        switch ekRule.frequency {
        case .daily:
            return RecurringRuleSchedule(frequency: .daily)
        case .weekly:
            let weekdays = ekRule.daysOfTheWeek?.map(\.dayOfTheWeek.rawValue) ?? []
            return mapWeeklyWeekdays(weekdays)
        default:
            return nil
        }
    }

    static func map(rrule: String) -> RecurringRuleSchedule? {
        let parts = rrule
            .split(separator: ";")
            .reduce(into: [String: String]()) { result, part in
                let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2 else { return }
                result[pair[0].uppercased()] = pair[1].uppercased()
            }

        guard let frequency = parts["FREQ"] else { return nil }

        switch frequency {
        case "DAILY":
            return RecurringRuleSchedule(frequency: .daily)
        case "WEEKLY":
            let weekdays = parseICSWeekdays(parts["BYDAY"] ?? "")
            return mapWeeklyWeekdays(weekdays)
        default:
            return nil
        }
    }

    static func reminderTime(from date: Date?, calendar: Calendar = .current) -> Date {
        guard let date else {
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
        }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private static func mapWeeklyWeekdays(_ weekdays: [Int]) -> RecurringRuleSchedule? {
        let sorted = Set(weekdays).sorted()
        guard !sorted.isEmpty else { return nil }

        if sorted == [2, 3, 4, 5, 6] {
            return RecurringRuleSchedule(frequency: .weekdays)
        }

        if sorted.count == 1, let weekday = sorted.first {
            return RecurringRuleSchedule(frequency: .weekly, weeklyWeekday: weekday)
        }

        var mask = 0
        for weekday in sorted {
            mask |= (1 << weekday)
        }
        return RecurringRuleSchedule(frequency: .custom, customWeekdaysMask: mask)
    }

    private static func parseICSWeekdays(_ value: String) -> [Int] {
        value
            .split(separator: ",")
            .compactMap { icsWeekdayToNumber(String($0)) }
    }

    private static func icsWeekdayToNumber(_ token: String) -> Int? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let dayToken = trimmed.count > 2 ? String(trimmed.suffix(2)) : trimmed

        switch dayToken {
        case "SU": return 1
        case "MO": return 2
        case "TU": return 3
        case "WE": return 4
        case "TH": return 5
        case "FR": return 6
        case "SA": return 7
        default: return nil
        }
    }
}

struct RecurringRuleSchedule: Equatable, Hashable {
    var frequency: RecurringFrequency
    var weeklyWeekday: Int = 2
    var customWeekdaysMask: Int = 0

    func summary(calendar: Calendar = .current) -> String {
        RecurringRule.frequencySummary(
            frequency: frequency,
            weeklyWeekday: weeklyWeekday,
            customWeekdaysMask: customWeekdaysMask
        )
    }

    func matchesExisting(_ rule: RecurringRule) -> Bool {
        rule.frequency == frequency
            && rule.weeklyWeekday == weeklyWeekday
            && rule.customWeekdaysMask == customWeekdaysMask
    }
}
