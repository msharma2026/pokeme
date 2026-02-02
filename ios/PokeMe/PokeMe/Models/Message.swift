import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let matchId: String
    let senderId: String
    let text: String
    let createdAt: String

    var isFromCurrentUser: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case matchId
        case senderId
        case text
        case createdAt
    }
}

struct MessagesResponse: Codable {
    let messages: [Message]
    let matchId: String
}

struct SendMessageRequest: Codable {
    let text: String
}

struct SendMessageResponse: Codable {
    let message: Message
}
