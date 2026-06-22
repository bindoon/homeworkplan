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
        apiKey: String
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
            "messages": messages
        ]
        if !tools.isEmpty {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentLLMServiceError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentLLMServiceError.apiError(statusCode: http.statusCode, message: message)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            throw AgentLLMServiceError.invalidResponse
        }

        let content = message["content"] as? String
        let toolCalls = parseToolCalls(from: message["tool_calls"])
        return AgentLLMResponse(content: content, toolCalls: toolCalls)
    }

    private func parseToolCalls(from value: Any?) -> [AgentToolCall] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { item in
            guard
                let id = item["id"] as? String,
                let function = item["function"] as? [String: Any],
                let name = function["name"] as? String
            else { return nil }

            let arguments: String
            if let argsString = function["arguments"] as? String {
                arguments = argsString
            } else if let argsObject = function["arguments"] as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: argsObject),
                      let encoded = String(data: data, encoding: .utf8) {
                arguments = encoded
            } else {
                arguments = "{}"
            }

            return AgentToolCall(id: id, name: name, argumentsJSON: arguments)
        }
    }
}
