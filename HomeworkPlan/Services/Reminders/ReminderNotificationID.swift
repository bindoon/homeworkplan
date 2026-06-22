import Foundation

enum ReminderNotificationID {
    static func morning(for taskId: UUID) -> String {
        "\(taskId.uuidString)-morning"
    }

    static func afternoon(for taskId: UUID) -> String {
        "\(taskId.uuidString)-afternoon"
    }

    static func recurring(for taskId: UUID) -> String {
        "\(taskId.uuidString)-recurring"
    }

    static func all(for taskId: UUID) -> [String] {
        [morning(for: taskId), afternoon(for: taskId), recurring(for: taskId)]
    }
}
