import Foundation

struct TaskCandidate: Codable, Identifiable, Equatable {
    var id: UUID
    var subjectName: String
    var content: String
    var dueDate: Date?
    var assigner: String?
    var confidence: Double
    var notes: String?
    var action: ImportTaskAction
    var matchedTaskId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case subjectName = "subject"
        case content
        case dueDate
        case assigner
        case confidence
        case notes
        case action
        case matchedTaskId
    }

    init(
        id: UUID = UUID(),
        subjectName: String,
        content: String,
        dueDate: Date? = nil,
        assigner: String? = nil,
        confidence: Double = 0.8,
        notes: String? = nil,
        action: ImportTaskAction = .create,
        matchedTaskId: UUID? = nil
    ) {
        self.id = id
        self.subjectName = subjectName
        self.content = content
        self.dueDate = dueDate
        self.assigner = assigner
        self.confidence = confidence
        self.notes = notes
        self.action = action
        self.matchedTaskId = matchedTaskId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        subjectName = try container.decodeIfPresent(String.self, forKey: .subjectName) ?? "其他"
        content = try container.decode(String.self, forKey: .content)
        dueDate = TaskCandidate.decodeDueDate(from: container)
        assigner = try container.decodeIfPresent(String.self, forKey: .assigner)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.8
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        action = try container.decodeIfPresent(ImportTaskAction.self, forKey: .action) ?? .create
        matchedTaskId = TaskCandidate.decodeMatchedTaskId(from: container)
    }

    private static func decodeMatchedTaskId(from container: KeyedDecodingContainer<CodingKeys>) -> UUID? {
        if let uuid = try? container.decodeIfPresent(UUID.self, forKey: .matchedTaskId) {
            return uuid
        }
        if let raw = try? container.decodeIfPresent(String.self, forKey: .matchedTaskId) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.lowercased() == "null" {
                return nil
            }
            return UUID(uuidString: trimmed)
        }
        return nil
    }

    private static func decodeDueDate(from container: KeyedDecodingContainer<CodingKeys>) -> Date? {
        if let iso = try? container.decodeIfPresent(String.self, forKey: .dueDate) {
            return TaskCandidate.parseLocalDateString(iso)
        }
        if let date = try? container.decodeIfPresent(Date.self, forKey: .dueDate) {
            return Calendar.current.startOfDay(for: date)
        }
        return nil
    }
}

struct TaskCandidateParseResponse: Codable {
    var tasks: [TaskCandidate]
    var message: String?

    enum CodingKeys: String, CodingKey {
        case tasks
        case message
    }

    init(tasks: [TaskCandidate], message: String? = nil) {
        self.tasks = tasks
        self.message = message
    }

    init(from decoder: Decoder) throws {
        if let array = try? [TaskCandidate](from: decoder) {
            tasks = array
            message = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([TaskCandidate].self, forKey: .tasks) ?? []
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}
