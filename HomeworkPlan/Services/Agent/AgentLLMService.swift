import Foundation

enum AgentLLMServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AI 服务未配置"
        case .invalidResponse:
            return "AI 返回无效响应"
        case .apiError(let code, let message):
            return "AI 请求失败（\(code)）：\(message)"
        }
    }
}

struct AgentLLMResponse {
    let content: String?
    let toolCalls: [AgentToolCall]
}

private struct AgentLLMStreamAccumulator {
    var content = ""
    private var toolCallParts: [Int: (id: String, name: String, arguments: String)] = [:]

    mutating func apply(eventJSON: [String: Any]) {
        guard
            let choices = eventJSON["choices"] as? [[String: Any]],
            let first = choices.first,
            let delta = first["delta"] as? [String: Any]
        else { return }

        if let piece = delta["content"] as? String {
            content += piece
        }

        guard let toolCallDeltas = delta["tool_calls"] as? [[String: Any]] else { return }
        for part in toolCallDeltas {
            let index = part["index"] as? Int ?? 0
            var existing = toolCallParts[index] ?? (id: "", name: "", arguments: "")

            if let id = part["id"] as? String, !id.isEmpty {
                existing.id = id
            }
            if let function = part["function"] as? [String: Any] {
                if let name = function["name"] as? String, !name.isEmpty {
                    existing.name = name
                }
                if let args = function["arguments"] as? String {
                    existing.arguments += args
                }
            }
            toolCallParts[index] = existing
        }
    }

    func buildResponse() -> AgentLLMResponse {
        let toolCalls = toolCallParts.keys.sorted().compactMap { index -> AgentToolCall? in
            guard let part = toolCallParts[index], !part.id.isEmpty, !part.name.isEmpty else {
                return nil
            }
            return AgentToolCall(id: part.id, name: part.name, argumentsJSON: part.arguments.isEmpty ? "{}" : part.arguments)
        }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return AgentLLMResponse(
            content: trimmedContent.isEmpty ? nil : content,
            toolCalls: toolCalls
        )
    }
}

actor AgentLLMService {
    static let shared = AgentLLMService()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 90
            configuration.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: configuration)
        }
    }

    private var endpoint: URL {
        let base = AppSecrets.dashscopeBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/chat/completions")!
    }

    func chat(
        messages: [[String: Any]],
        tools: [[String: Any]],
        apiKey: String,
        onContentDelta: (@Sendable (String) async -> Void)? = nil
    ) async throws -> AgentLLMResponse {
        try await chatStream(
            messages: messages,
            tools: tools,
            apiKey: apiKey,
            onContentDelta: onContentDelta
        )
    }

    private func chatStream(
        messages: [[String: Any]],
        tools: [[String: Any]],
        apiKey: String,
        onContentDelta: (@Sendable (String) async -> Void)?
    ) async throws -> AgentLLMResponse {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw AgentLLMServiceError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": AppSecrets.llmModel,
            "temperature": 0.2,
            "stream": true,
            "messages": messages
        ]
        if !tools.isEmpty {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentLLMServiceError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let message = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AgentLLMServiceError.apiError(statusCode: http.statusCode, message: message)
        }

        var accumulator = AgentLLMStreamAccumulator()
        var previousContentLength = 0

        for try await line in bytes.lines {
            try Task.checkCancellation()

            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard
                let data = payload.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            accumulator.apply(eventJSON: json)

            if let onContentDelta, accumulator.content.count > previousContentLength {
                previousContentLength = accumulator.content.count
                await onContentDelta(accumulator.content)
            }
        }

        let result = accumulator.buildResponse()
        if result.toolCalls.isEmpty, result.content == nil {
            throw AgentLLMServiceError.invalidResponse
        }
        return result
    }
}
