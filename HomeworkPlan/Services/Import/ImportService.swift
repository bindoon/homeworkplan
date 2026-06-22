import Foundation
import UIKit

struct ImportResult {
    let importRecord: ImportRecord?
    let candidates: [TaskCandidate]
    let rawText: String
    let isDuplicate: Bool
    let parseFailed: Bool
    let message: String?
    let sourceType: ImportSourceType
    let sourceImagePath: String
}

enum ImportServiceError: LocalizedError {
    case missingAPIKey
    case duplicateContent
    case emptyText

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AI 解析服务未配置，请检查本地 Secrets.env 或在设置中填写 API Key"
        case .duplicateContent:
            return "该内容已导入过，无需重复解析"
        case .emptyText:
            return "导入内容为空"
        }
    }
}

@MainActor
final class ImportService {
    private let importRepository: ImportRepository
    private let taskRepository: TaskRepository
    private let keychainService: KeychainService
    private let parseService: ParseService

    init(
        importRepository: ImportRepository,
        taskRepository: TaskRepository,
        keychainService: KeychainService,
        parseService: ParseService = .shared
    ) {
        self.importRepository = importRepository
        self.taskRepository = taskRepository
        self.keychainService = keychainService
        self.parseService = parseService
    }

    func processImage(_ image: UIImage) async throws -> ImportResult {
        guard let apiKey = resolveAPIKey() else {
            throw ImportServiceError.missingAPIKey
        }

        do {
            let text = try await OCRService.recognizeText(from: image)
            return try await processText(text, sourceType: .screenshot, sourceImage: image)
        } catch let error as OCRServiceError {
            guard AppSecrets.hasVisionModel,
                  let jpegData = image.fixedOrientation().jpegData(compressionQuality: 0.85) else {
                throw error
            }
            return try await processScreenshotWithVision(
                image: image,
                jpegData: jpegData,
                apiKey: apiKey
            )
        }
    }

    func processPastedText(_ text: String) async throws -> ImportResult {
        try await processText(text, sourceType: .pasted)
    }

    private func processText(
        _ text: String,
        sourceType: ImportSourceType,
        sourceImage: UIImage? = nil
    ) async throws -> ImportResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportServiceError.emptyText
        }

        guard let apiKey = resolveAPIKey() else {
            throw ImportServiceError.missingAPIKey
        }

        let hash = ContentHashService.sha256(trimmed)
        if let existing = try importRepository.findByContentHash(hash) {
            let candidates = decodeCandidates(from: existing.parsedJSON)
            if sourceType == .screenshot, existing.imagePath.isEmpty, let sourceImage {
                attachImage(sourceImage, to: existing)
            }
            return ImportResult(
                importRecord: existing,
                candidates: candidates,
                rawText: existing.rawText,
                isDuplicate: true,
                parseFailed: candidates.isEmpty && existing.parsedJSON == nil,
                message: candidates.isEmpty ? "该内容已导入过" : nil,
                sourceType: ImportSourceType(rawValue: existing.sourceType) ?? sourceType,
                sourceImagePath: existing.imagePath
            )
        }

        let importedAt = Date()
        let existingTasks = loadExistingTaskContext(referenceDate: importedAt)
        var parseFailed = false
        var message: String?
        var candidates: [TaskCandidate] = []
        var parsedJSON: String?

        do {
            let response = try await parseService.parse(
                text: trimmed,
                importedAt: importedAt,
                existingTasks: existingTasks,
                apiKey: apiKey
            )
            candidates = response.tasks
            message = response.message
            parsedJSON = encodeCandidates(candidates, message: message)
            if candidates.isEmpty {
                parseFailed = true
            }
        } catch {
            parseFailed = true
            message = error.localizedDescription
        }

        let record = try importRepository.createRecord(
            contentHash: hash,
            rawText: trimmed,
            sourceType: sourceType,
            parsedJSON: parsedJSON
        )

        if sourceType == .screenshot, let sourceImage {
            attachImage(sourceImage, to: record)
        }

        return ImportResult(
            importRecord: record,
            candidates: candidates,
            rawText: trimmed,
            isDuplicate: false,
            parseFailed: parseFailed,
            message: message,
            sourceType: sourceType,
            sourceImagePath: record.imagePath
        )
    }

    private func processScreenshotWithVision(
        image: UIImage,
        jpegData: Data,
        apiKey: String
    ) async throws -> ImportResult {
        let hash = ContentHashService.sha256(data: jpegData)
        if let existing = try importRepository.findByContentHash(hash) {
            let candidates = decodeCandidates(from: existing.parsedJSON)
            if existing.imagePath.isEmpty {
                attachImage(image, to: existing)
            }
            return ImportResult(
                importRecord: existing,
                candidates: candidates,
                rawText: existing.rawText,
                isDuplicate: true,
                parseFailed: candidates.isEmpty && existing.parsedJSON == nil,
                message: candidates.isEmpty ? "该内容已导入过" : nil,
                sourceType: .screenshot,
                sourceImagePath: existing.imagePath
            )
        }

        let importedAt = Date()
        let existingTasks = loadExistingTaskContext(referenceDate: importedAt)
        var parseFailed = false
        var message: String?
        var candidates: [TaskCandidate] = []
        var parsedJSON: String?
        var rawText = "[截图识图导入]"

        do {
            let response = try await parseService.parseImage(
                image,
                importedAt: importedAt,
                existingTasks: existingTasks,
                apiKey: apiKey
            )
            candidates = response.tasks
            message = response.message
            parsedJSON = encodeCandidates(candidates, message: message)
            if !candidates.isEmpty {
                rawText = candidates.map(\.content).joined(separator: "\n")
            } else if let message, !message.isEmpty {
                rawText = message
            }
            if candidates.isEmpty {
                parseFailed = true
            }
        } catch {
            parseFailed = true
            message = error.localizedDescription
            throw error
        }

        let record = try importRepository.createRecord(
            contentHash: hash,
            rawText: rawText,
            sourceType: .screenshot,
            parsedJSON: parsedJSON
        )
        attachImage(image, to: record)

        return ImportResult(
            importRecord: record,
            candidates: candidates,
            rawText: rawText,
            isDuplicate: false,
            parseFailed: parseFailed,
            message: message,
            sourceType: .screenshot,
            sourceImagePath: record.imagePath
        )
    }

    private func attachImage(_ image: UIImage, to record: ImportRecord) {
        do {
            let path = try ImportImageStore.save(image, recordID: record.id)
            try importRepository.updateImagePath(recordID: record.id, path: path)
            record.imagePath = path
        } catch {
            print("Failed to attach import image: \(error)")
        }
    }

    private func loadExistingTaskContext(referenceDate: Date) -> [ExistingTaskContextItem] {
        do {
            let tasks = try taskRepository.fetchRecentForImportContext(from: referenceDate)
            return ImportContextBuilder.build(from: tasks)
        } catch {
            print("Failed to load import context tasks: \(error)")
            return []
        }
    }

    private func resolveAPIKey() -> String? {
        if let keychainKey = keychainService.loadAPIKey() {
            let trimmed = keychainKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        if AppSecrets.isConfigured {
            return AppSecrets.dashscopeAPIKey
        }
        return nil
    }

    private func decodeCandidates(from json: String?) -> [TaskCandidate] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let wrapper = try? decoder.decode(TaskCandidateParseResponse.self, from: data) {
            return wrapper.tasks
        }
        return (try? decoder.decode([TaskCandidate].self, from: data)) ?? []
    }

    private func encodeCandidates(_ candidates: [TaskCandidate], message: String?) -> String? {
        let wrapper = TaskCandidateParseResponse(tasks: candidates, message: message)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(wrapper) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
