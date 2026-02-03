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

    func addReaction(token: String, messageId: String, emoji: String) async throws -> AddReactionResponse {
        let request = AddReactionRequest(emoji: emoji)
        return try await NetworkService.shared.request(
            endpoint: "\(Constants.Endpoints.messages)/\(messageId)/reactions",
            method: .POST,
            body: request,
            token: token
        )
    }

    func removeReaction(token: String, messageId: String, emoji: String) async throws {
        // URL encode the emoji for the path
        let encodedEmoji = emoji.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? emoji
        let _: RemoveReactionResponse = try await NetworkService.shared.request(
            endpoint: "\(Constants.Endpoints.messages)/\(messageId)/reactions/\(encodedEmoji)",
            method: .DELETE,
            token: token
        )
    }

    func markMessagesRead(token: String, messageIds: [String]) async throws -> MarkReadResponse {
        let request = MarkReadRequest(messageIds: messageIds)
        return try await NetworkService.shared.request(
            endpoint: "\(Constants.Endpoints.messages)/read",
            method: .POST,
            body: request,
            token: token
        )
    }

    func updateTyping(token: String, isTyping: Bool) async throws -> TypingUpdateResponse {
        let request = TypingRequest(isTyping: isTyping)
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.typing,
            method: .POST,
            body: request,
            token: token
        )
    }

    func getTypingStatus(token: String) async throws -> TypingStatusResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.typing,
            method: .GET,
            token: token
        )
    }
}
	
	
