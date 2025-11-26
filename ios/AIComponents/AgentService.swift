//
//  AgentService.swift
//  AIComponents
//
//  Created by Martin Mitrevski on 28.10.25.
//

import Foundation
import MCP
import StreamChatAI

class AgentService {
    static let shared = AgentService()
    
    private let baseURL = "http://localhost:3000"
    
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    private let urlSession = URLSession.shared
    
    func setupAgent(channelId: String, model: String? = nil) async throws {
        try await executePostRequest(
            body: AIAgentRequest(channelId: channelId, model: model),
            endpoint: "start-ai-agent"
        )
    }
    
    func stopAgent(channelId: String) async throws {
        try await executePostRequest(
            body: AIAgentRequest(channelId: channelId, model: nil),
            endpoint: "stop-ai-agent"
        )
    }

    func registerTools(channelId: String, tools: [ToolRegistrationPayload]) async throws {
        guard !tools.isEmpty else { return }
        try await executePostRequest(
            body: ToolRegistrationRequest(channelId: channelId, tools: tools),
            endpoint: "register-tools"
        )
    }

    func summarize(text: String, platform: String, model: String? = nil) async throws -> String {
        let data = try await executePostRequestWithResponse(
            body: AgentSummaryRequest(text: text, platform: platform, model: model),
            endpoint: "summarize"
        )

        let response = try jsonDecoder.decode(AgentSummaryResponse.self, from: data)
        return response.summary
    }
    
    private func executePostRequest<RequestBody: Encodable>(body: RequestBody, endpoint: String) async throws {
        _ = try await executePostRequestWithResponse(body: body, endpoint: endpoint)
    }
    
    private func executePostRequestWithResponse<RequestBody: Encodable>(body: RequestBody, endpoint: String) async throws -> Data {
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(body)
        let (data, _) = try await urlSession.data(for: request)
        return data
    }
}

struct AIAgentRequest: Encodable {
    let channelId: String
    let platform: String = "openai"
    let model: String?
    
    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case platform
        case model
    }
}

struct AgentSummaryRequest: Encodable {
    let text: String
    let platform: String
    let model: String?
}

struct AgentSummaryResponse: Decodable {
    let summary: String
}

struct ToolRegistrationRequest: Encodable {
    let channelId: String
    let tools: [ToolRegistrationPayload]

    enum CodingKeys: String, CodingKey {
        case channelId = "channel_id"
        case tools
    }
}
