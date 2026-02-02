import Foundation

class AuthService {
    static let shared = AuthService()

    private init() {}

    func register(email: String, password: String, displayName: String, major: String?) async throws -> AuthResponse {
        var body: [String: Any] = [
            "email": email,
            "password": password,
            "displayName": displayName
        ]

        if let major = major, !major.isEmpty {
            body["major"] = major
        }

        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.register,
            method: .POST,
            body: body
        )
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.login,
            method: .POST,
            body: body
        )
    }

    func getMe(token: String) async throws -> User {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.me,
            method: .GET,
            token: token
        )
    }
}
