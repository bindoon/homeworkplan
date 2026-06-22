import Foundation
import UIKit

enum ParseServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case invalidImage
    case apiError(statusCode: Int, message: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AI 解析服务未配置"
        case .invalidResponse:
            return "解析服务返回无效响应"
        case .invalidImage:
            return "无法处理截图"
        case .apiError(let code, let message):
            return "解析请求失败（\(code)）：\(message)"
        case .decodingFailed:
            return "无法解析 AI 返回的作业结构"
        }
    }
}

actor ParseService {
    static let shared = ParseService()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 90
            self.session = URLSession(configuration: configuration)
        }
    }

    private var endpoint: URL {
        let base = AppSecrets.dashscopeBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/chat/completions")!
    }

    func parse(
        text: String,
        importedAt: Date,
        existingTasks: [ExistingTaskContextItem] = [],
        apiKey: String
    ) async throws -> TaskCandidateParseResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw ParseServiceError.missingAPIKey
        }

        do {
            return try await requestTextParse(
                text: text,
                importedAt: importedAt,
                existingTasks: existingTasks,
                apiKey: trimmedKey,
                strict: false
            )
        } catch ParseServiceError.decodingFailed {
            return try await requestTextParse(
                text: text,
                importedAt: importedAt,
                existingTasks: existingTasks,
                apiKey: trimmedKey,
                strict: true
            )
        }
    }

    func parseImage(
        _ image: UIImage,
        importedAt: Date,
        existingTasks: [ExistingTaskContextItem] = [],
        apiKey: String
    ) async throws -> TaskCandidateParseResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw ParseServiceError.missingAPIKey
        }
        guard AppSecrets.hasVisionModel else {
            throw ParseServiceError.invalidResponse
        }
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            throw ParseServiceError.invalidImage
        }

        let base64 = jpegData.base64EncodedString()

        do {
            return try await requestVisionParse(
                base64JPEG: base64,
                importedAt: importedAt,
                existingTasks: existingTasks,
                apiKey: trimmedKey,
                strict: false
            )
        } catch ParseServiceError.decodingFailed {
            return try await requestVisionParse(
                base64JPEG: base64,
                importedAt: importedAt,
                existingTasks: existingTasks,
                apiKey: trimmedKey,
                strict: true
            )
        }
    }

    static func decodeResponseContent(_ content: String) throws -> TaskCandidateParseResponse {
        let trimmed = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = trimmed.data(using: .utf8) else {
            throw ParseServiceError.decodingFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let response = try? decoder.decode(TaskCandidateParseResponse.self, from: data) {
            return response
        }

        if let tasks = try? decoder.decode([TaskCandidate].self, from: data) {
            return TaskCandidateParseResponse(tasks: tasks)
        }

        throw ParseServiceError.decodingFailed
    }

    private func requestTextParse(
        text: String,
        importedAt: Date,
        existingTasks: [ExistingTaskContextItem],
        apiKey: String,
        strict: Bool
    ) async throws -> TaskCandidateParseResponse {
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": ParsePrompt.systemPrompt(
                    importedAt: importedAt,
                    existingTasks: existingTasks,
                    strict: strict
                )
            ],
            [
                "role": "user",
                "content": ParsePrompt.userPrompt(text: text)
            ]
        ]

        return try await performChatCompletion(
            model: AppSecrets.llmModel,
            apiKey: apiKey,
            messages: messages
        )
    }

    private func requestVisionParse(
        base64JPEG: String,
        importedAt: Date,
        existingTasks: [ExistingTaskContextItem],
        apiKey: String,
        strict: Bool
    ) async throws -> TaskCandidateParseResponse {
        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": ParsePrompt.systemPrompt(
                    importedAt: importedAt,
                    existingTasks: existingTasks,
                    strict: strict
                )
            ],
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": ParsePrompt.imageUserPrompt()
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64JPEG)"
                        ]
                    ]
                ]
            ]
        ]

        return try await performChatCompletion(
            model: AppSecrets.visionModel,
            apiKey: apiKey,
            messages: messages
        )
    }

    private func performChatCompletion(
        model: String,
        apiKey: String,
        messages: [[String: Any]]
    ) async throws -> TaskCandidateParseResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "response_format": ["type": "json_object"],
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ParseServiceError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ParseServiceError.apiError(statusCode: http.statusCode, message: message)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw ParseServiceError.invalidResponse
        }

        return try Self.decodeResponseContent(content)
    }
}
