import Foundation

/// UserDefaults-backed default reminder times for due-date tasks.
struct ReminderSettings {
    private enum Keys {
        static let morningHour = "morningReminderHour"
        static let morningMinute = "morningReminderMinute"
        static let afternoonHour = "afternoonReminderHour"
        static let afternoonMinute = "afternoonReminderMinute"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaultsIfNeeded()
    }

    private func registerDefaultsIfNeeded() {
        defaults.register(defaults: [
            Keys.morningHour: 8,
            Keys.morningMinute: 0,
            Keys.afternoonHour: 17,
            Keys.afternoonMinute: 0
        ])
    }

    var morningHour: Int {
        get { defaults.integer(forKey: Keys.morningHour) }
        set { defaults.set(newValue, forKey: Keys.morningHour) }
    }

    var morningMinute: Int {
        get { defaults.integer(forKey: Keys.morningMinute) }
        set { defaults.set(newValue, forKey: Keys.morningMinute) }
    }

    var afternoonHour: Int {
        get { defaults.integer(forKey: Keys.afternoonHour) }
        set { defaults.set(newValue, forKey: Keys.afternoonHour) }
    }

    var afternoonMinute: Int {
        get { defaults.integer(forKey: Keys.afternoonMinute) }
        set { defaults.set(newValue, forKey: Keys.afternoonMinute) }
    }

    func morningTime(on date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(
            bySettingHour: morningHour,
            minute: morningMinute,
            second: 0,
            of: calendar.startOfDay(for: date)
        )
    }

    func afternoonTime(on date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(
            bySettingHour: afternoonHour,
            minute: afternoonMinute,
            second: 0,
            of: calendar.startOfDay(for: date)
        )
    }

    func reminderTimeDate(hour: Int, minute: Int, calendar: Calendar = .current) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    var morningReminderDate: Date {
        reminderTimeDate(hour: morningHour, minute: morningMinute)
    }

    var afternoonReminderDate: Date {
        reminderTimeDate(hour: afternoonHour, minute: afternoonMinute)
    }

    func setMorningReminder(from date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        morningHour = components.hour ?? 8
        morningMinute = components.minute ?? 0
    }

    func setAfternoonReminder(from date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        afternoonHour = components.hour ?? 17
        afternoonMinute = components.minute ?? 0
    }
}
