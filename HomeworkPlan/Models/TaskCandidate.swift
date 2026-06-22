import Foundation

struct TaskCandidate: Codable, Identifiable, Equatable {
    var id: UUID
    var subjectName: String
    var content: String
    var dueDate: Date?
    var assigner: String?
    var confidence: Double
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case subjectName = "subject"
        case content
        case dueDate
        case assigner
        case confidence
        case notes
    }

    init(
        id: UUID = UUID(),
        subjectName: String,
        content: String,
        dueDate: Date? = nil,
        assigner: String? = nil,
        confidence: Double = 0.8,
        notes: String? = nil
    ) {
        self.id = id
        self.subjectName = subjectName
        self.content = content
        self.dueDate = dueDate
        self.assigner = assigner
        self.confidence = confidence
        self.notes = notes
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
    }

    private static func decodeDueDate(from container: KeyedDecodingContainer<CodingKeys>) -> Date? {
        if let date = try? container.decodeIfPresent(Date.self, forKey: .dueDate) {
            return date
        }
        if let iso = try? container.decodeIfPresent(String.self, forKey: .dueDate),
           !iso.isEmpty {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            if let parsed = formatter.date(from: iso) {
                return parsed
            }
            let fallback = DateFormatter()
            fallback.locale = Locale(identifier: "en_US_POSIX")
            fallback.dateFormat = "yyyy-MM-dd"
            return fallback.date(from: iso)
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
