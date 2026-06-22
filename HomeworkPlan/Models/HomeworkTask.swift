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
    var sourceType: String = "manual"
    var createdAt: Date = Date()

    init() {}

    init(
        subject: Subject?,
        content: String,
        notes: String = "",
        dueDate: Date,
        sourceType: String = "manual"
    ) {
        self.id = UUID()
        self.subject = subject
        self.content = content
        self.notes = notes
        self.dueDate = dueDate
        self.sourceType = sourceType
        self.createdAt = Date()
    }
}
