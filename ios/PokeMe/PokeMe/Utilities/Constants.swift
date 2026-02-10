import Foundation

enum Constants {
    // For local development: "http://localhost:8080/api"
    // For App Engine: "https://pokeme-191.appspot.com/api"
    static let baseURL = "https://pokeme-191.appspot.com/api"

    enum Endpoints {
        static let register = "/auth/register"
        static let login = "/auth/login"
        static let me = "/auth/me"
        static let profile = "/auth/profile"
        static let profilePicture = "/auth/profile-picture"
        static let discover = "/discover"
        static let matches = "/matches"
        static let incomingPokes = "/pokes/incoming"
        static let adminReset = "/admin/reset"

        static func poke(_ userId: String) -> String { "/poke/\(userId)" }
        static func messages(_ matchId: String) -> String { "/matches/\(matchId)/messages" }
        static func typing(_ matchId: String) -> String { "/matches/\(matchId)/typing" }
        static func reactions(_ matchId: String, _ messageId: String) -> String {
            "/matches/\(matchId)/messages/\(messageId)/reactions"
        }
        static func removeReaction(_ matchId: String, _ messageId: String, _ emoji: String) -> String {
            let encoded = emoji.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? emoji
            return "/matches/\(matchId)/messages/\(messageId)/reactions/\(encoded)"
        }
        static func markRead(_ matchId: String) -> String { "/matches/\(matchId)/messages/read" }
    }

    enum StorageKeys {
        static let authToken = "auth_token"
        static let currentUser = "current_user"
    }
}
