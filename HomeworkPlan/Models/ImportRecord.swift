import Foundation
import SwiftData

@Model
final class ImportRecord {
    var id: UUID = UUID()
    var contentHash: String = ""
    var rawText: String = ""
    var sourceType: String = ImportSourceType.pasted.rawValue
    var parsedJSON: String? = nil
    var imagePath: String = ""
    var createdAt: Date = Date()
    var linkedTaskIDs: String = ""

    init() {}

    init(
        contentHash: String,
        rawText: String,
        sourceType: ImportSourceType,
        parsedJSON: String? = nil
    ) {
        self.id = UUID()
        self.contentHash = contentHash
        self.rawText = rawText
        self.sourceType = sourceType.rawValue
        self.parsedJSON = parsedJSON
        self.createdAt = Date()
    }

    var linkedTaskIDList: [UUID] {
        guard !linkedTaskIDs.isEmpty else { return [] }
        return linkedTaskIDs
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }

    func appendLinkedTaskID(_ taskID: UUID) {
        var ids = linkedTaskIDList
        guard !ids.contains(taskID) else { return }
        ids.append(taskID)
        linkedTaskIDs = ids.map(\.uuidString).joined(separator: ",")
    }
}
