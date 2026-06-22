import Foundation
import SwiftData

@Model
final class HomeworkTask {
    var id: UUID = UUID()
    var subject: Subject?
    var content: String = ""
    var notes: String = ""
    var dueDate: Date = Date()
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var sourceType: String = ImportSourceType.manual.rawValue
    var sourceDetail: String = ""
    var sourceImagePath: String = ""
    var recurringRuleId: UUID? = nil
    var generationKey: String = ""
    var createdAt: Date = Date()

    init() {}

    init(
        subject: Subject?,
        content: String,
        notes: String = "",
        dueDate: Date,
        sourceType: String = ImportSourceType.manual.rawValue,
        sourceDetail: String = "",
        sourceImagePath: String = "",
        recurringRuleId: UUID? = nil,
        generationKey: String = ""
    ) {
        self.id = UUID()
        self.subject = subject
        self.content = content
        self.notes = notes
        self.dueDate = dueDate
        self.sourceType = sourceType
        self.sourceDetail = sourceDetail
        self.sourceImagePath = sourceImagePath
        self.recurringRuleId = recurringRuleId
        self.generationKey = generationKey
        self.createdAt = Date()
    }

    static func makeGenerationKey(ruleId: UUID, date: Date, calendar: Calendar = .current) -> String {
        let dayStart = calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(ruleId.uuidString)-\(formatter.string(from: dayStart))"
    }
}
