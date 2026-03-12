import Foundation

final class MessageCache {
    static let shared = MessageCache()
    private init() {}

    private var messages: [String: [Message]] = [:]
    private var timestamps: [String: String] = [:]

    func getMessages(for matchId: String) -> [Message]? {
        return messages[matchId]
    }

    func getTimestamp(for matchId: String) -> String? {
        return timestamps[matchId]
    }

    func update(matchId: String, messages: [Message], timestamp: String?) {
        self.messages[matchId] = messages
        if let ts = timestamp {
            self.timestamps[matchId] = ts
        }
    }
}
