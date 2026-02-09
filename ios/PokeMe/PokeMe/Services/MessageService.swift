import Foundation

class MessageService {
    static let shared = MessageService()

    private init() {}

    func getMessages(token: String, matchId: String) async throws -> MessagesResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.messages(matchId),
            method: .GET,
            token: token
        )
    }

    func sendMessage(token: String, matchId: String, text: String) async throws -> SendMessageResponse {
        let request = SendMessageRequest(text: text)
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.messages(matchId),
            method: .POST,
            body: request,
            token: token
        )
    }

    func addReaction(token: String, matchId: String, messageId: String, emoji: String) async throws -> AddReactionResponse {
        let request = AddReactionRequest(emoji: emoji)
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.reactions(matchId, messageId),
            method: .POST,
            body: request,
            token: token
        )
    }

    func removeReaction(token: String, matchId: String, messageId: String, emoji: String) async throws {
        let _: RemoveReactionResponse = try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.removeReaction(matchId, messageId, emoji),
            method: .DELETE,
            token: token
        )
    }

    func markMessagesRead(token: String, matchId: String, messageIds: [String]) async throws -> MarkReadResponse {
        let request = MarkReadRequest(messageIds: messageIds)
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.markRead(matchId),
            method: .POST,
            body: request,
            token: token
        )
    }

    func updateTyping(token: String, matchId: String, isTyping: Bool) async throws -> TypingUpdateResponse {
        let request = TypingRequest(isTyping: isTyping)
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.typing(matchId),
            method: .POST,
            body: request,
            token: token
        )
    }

    func getTypingStatus(token: String, matchId: String) async throws -> TypingStatusResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.typing(matchId),
            method: .GET,
            token: token
        )
    }
}
