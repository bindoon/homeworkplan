import Foundation
import SwiftData

@Model
final class Subject {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "📚"
    var sortOrder: Int = 0
    var isDefault: Bool = false
    var normalizedName: String = ""

    @Relationship(inverse: \HomeworkTask.subject)
    var tasks: [HomeworkTask]? = []

    init() {}

    init(
        name: String,
        emoji: String,
        sortOrder: Int,
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.normalizedName = Subject.normalizeName(name)
    }

    static func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum SubjectError: LocalizedError {
    case duplicateName
    case cannotDeleteDefault
    case emptyName
    case notFound

    var errorDescription: String? {
        switch self {
        case .duplicateName:
            return "科目名称已存在"
        case .cannotDeleteDefault:
            return "默认科目不可删除"
        case .emptyName:
            return "科目名称不能为空"
        case .notFound:
            return "科目不存在"
        }
    }
}
