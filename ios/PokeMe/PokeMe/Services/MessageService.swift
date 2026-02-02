import Foundation

class MessageService {
    static let shared = MessageService()

    private init() {}

    func getMessages(token: String) async throws -> MessagesResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.messages,
            method: .GET,
            token: token
        )
    }

    func sendMessage(token: String, text: String) async throws -> SendMessageResponse {
        let request = SendMessageRequest(text: text)
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.messages,
            method: .POST,
            body: request,
            token: token
        )
    }
}
