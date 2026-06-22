import Foundation
import SwiftData

@MainActor
final class ImportRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func createRecord(
        contentHash: String,
        rawText: String,
        sourceType: ImportSourceType,
        parsedJSON: String? = nil,
        imagePath: String = ""
    ) throws -> ImportRecord {
        let record = ImportRecord(
            contentHash: contentHash,
            rawText: rawText,
            sourceType: sourceType,
            parsedJSON: parsedJSON
        )
        record.imagePath = imagePath
        context.insert(record)
        try context.save()
        return record
    }

    func updateImagePath(recordID: UUID, path: String) throws {
        guard let record = try fetchRecord(id: recordID) else { return }
        record.imagePath = path
        try context.save()
    }

    func findByContentHash(_ hash: String) throws -> ImportRecord? {
        let descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { $0.contentHash == hash },
            sortBy: [SortDescriptor(\ImportRecord.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    func updateParsedJSON(recordID: UUID, json: String) throws {
        guard let record = try fetchRecord(id: recordID) else { return }
        record.parsedJSON = json
        try context.save()
    }

    func linkTask(recordID: UUID, taskID: UUID) throws {
        guard let record = try fetchRecord(id: recordID) else { return }
        record.appendLinkedTaskID(taskID)
        try context.save()
    }

    func fetchRecord(id: UUID) throws -> ImportRecord? {
        let descriptor = FetchDescriptor<ImportRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}
