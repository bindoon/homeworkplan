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
}

enum ImportServiceError: LocalizedError {
    case missingAPIKey
    case duplicateContent
    case emptyText

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中配置 DeepSeek API Key"
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
    private let keychainService: KeychainService
    private let parseService: ParseService

    init(
        importRepository: ImportRepository,
        keychainService: KeychainService,
        parseService: ParseService = .shared
    ) {
        self.importRepository = importRepository
        self.keychainService = keychainService
        self.parseService = parseService
    }

    func processImage(_ image: UIImage) async throws -> ImportResult {
        let text = try await OCRService.recognizeText(from: image)
        return try await processText(text, sourceType: .screenshot)
    }

    func processPastedText(_ text: String) async throws -> ImportResult {
        try await processText(text, sourceType: .pasted)
    }

    private func processText(_ text: String, sourceType: ImportSourceType) async throws -> ImportResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportServiceError.emptyText
        }

        guard keychainService.hasAPIKey(), let apiKey = keychainService.loadAPIKey() else {
            throw ImportServiceError.missingAPIKey
        }

        let hash = ContentHashService.sha256(trimmed)
        if let existing = try importRepository.findByContentHash(hash) {
            let candidates = decodeCandidates(from: existing.parsedJSON)
            return ImportResult(
                importRecord: existing,
                candidates: candidates,
                rawText: existing.rawText,
                isDuplicate: true,
                parseFailed: candidates.isEmpty && existing.parsedJSON == nil,
                message: candidates.isEmpty ? "该内容已导入过" : nil,
                sourceType: ImportSourceType(rawValue: existing.sourceType) ?? sourceType
            )
        }

        let importedAt = Date()
        var parseFailed = false
        var message: String?
        var candidates: [TaskCandidate] = []
        var parsedJSON: String?

        do {
            let response = try await parseService.parse(
                text: trimmed,
                importedAt: importedAt,
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

        return ImportResult(
            importRecord: record,
            candidates: candidates,
            rawText: trimmed,
            isDuplicate: false,
            parseFailed: parseFailed,
            message: message,
            sourceType: sourceType
        )
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
