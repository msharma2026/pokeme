import Foundation

class MatchService {
    static let shared = MatchService()

    private init() {}

    func getTodayMatch(token: String) async throws -> MatchResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.todayMatch,
            method: .GET,
            token: token
        )
    }

    func disconnect(token: String) async throws -> DisconnectResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.disconnect,
            method: .POST,
            token: token
        )
    }

    func poke(token: String) async throws -> PokeResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.poke,
            method: .POST,
            token: token
        )
    }
}
