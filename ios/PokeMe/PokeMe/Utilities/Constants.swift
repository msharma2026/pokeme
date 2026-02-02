import Foundation

enum Constants {
    // For local development: "http://localhost:8080/api"
    // For App Engine: "https://pokeme-191.appspot.com/api"
    static let baseURL = "https://pokeme-191.appspot.com/api"

    enum Endpoints {
        static let register = "/auth/register"
        static let login = "/auth/login"
        static let me = "/auth/me"
        static let todayMatch = "/match/today"
        static let disconnect = "/match/disconnect"
        static let poke = "/match/poke"
    }

    enum StorageKeys {
        static let authToken = "auth_token"
        static let currentUser = "current_user"
    }
}
