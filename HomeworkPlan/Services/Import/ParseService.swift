import Foundation

enum ParseServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中配置 DeepSeek API Key"
        case .invalidResponse:
            return "解析服务返回无效响应"
        case .apiError(let code, let message):
            return "解析请求失败（\(code)）：\(message)"
        case .decodingFailed:
            return "无法解析 AI 返回的作业结构"
        }
    }
}

actor ParseService {
    static let shared = ParseService()

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private let model = "deepseek-chat"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func parse(text: String, importedAt: Date, apiKey: String) async throws -> TaskCandidateParseResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw ParseServiceError.missingAPIKey
        }

        do {
            return try await requestParse(
                text: text,
                importedAt: importedAt,
                apiKey: trimmedKey,
                strict: false
            )
        } catch ParseServiceError.decodingFailed {
            return try await requestParse(
                text: text,
                importedAt: importedAt,
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

    private func requestParse(
        text: String,
        importedAt: Date,
        apiKey: String,
        strict: Bool
    ) async throws -> TaskCandidateParseResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "response_format": ["type": "json_object"],
            "messages": [
                [
                    "role": "system",
                    "content": ParsePrompt.systemPrompt(importedAt: importedAt, strict: strict)
                ],
                [
                    "role": "user",
                    "content": ParsePrompt.userPrompt(text: text)
                ]
            ]
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
