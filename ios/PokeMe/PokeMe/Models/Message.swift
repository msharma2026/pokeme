import Foundation

struct Reaction: Codable, Identifiable {
    let emoji: String
    let userId: String
    let createdAt: String

    var id: String { "\(userId)_\(emoji)" }
}

struct Message: Codable, Identifiable {
    let id: String
    let matchId: String
    let senderId: String
    let text: String
    let createdAt: String
    var readBy: [String]?
    var reactions: [Reaction]?

    var isFromCurrentUser: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case matchId
        case senderId
        case text
        case createdAt
        case readBy
        case reactions
    }

    /// Check if this message has been read by the partner (someone other than the sender)
    func isReadByPartner(currentUserId: String) -> Bool {
        guard let readBy = readBy else { return false }
        // If there's anyone in readBy other than the sender, it's been read by partner
        return readBy.contains { $0 != senderId }
    }
}

struct MessagesResponse: Codable {
    let messages: [Message]
    let matchId: String
    let partnerIsTyping: Bool?
}

struct SendMessageRequest: Codable {
    let text: String
}

struct SendMessageResponse: Codable {
    let message: Message
}

// MARK: - Reaction Request/Response

struct AddReactionRequest: Codable {
    let emoji: String
}

struct AddReactionResponse: Codable {
    let reaction: Reaction
}

// MARK: - Read Receipts Request/Response

struct MarkReadRequest: Codable {
    let messageIds: [String]
}

struct MarkReadResponse: Codable {
    let updatedCount: Int
}

// MARK: - Typing Request/Response

struct TypingRequest: Codable {
    let isTyping: Bool
}

struct TypingStatusResponse: Codable {
    let partnerIsTyping: Bool
}

struct TypingUpdateResponse: Codable {
    let isTyping: Bool
}

struct RemoveReactionResponse: Codable {
    let message: String
}
