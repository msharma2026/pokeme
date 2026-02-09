import Foundation

class MatchService {
    static let shared = MatchService()

    private init() {}

    func discover(token: String, sport: String? = nil) async throws -> DiscoverResponse {
        var endpoint = Constants.Endpoints.discover
        if let sport = sport {
            let encoded = sport.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sport
            endpoint += "?sport=\(encoded)"
        }
        return try await NetworkService.shared.request(
            endpoint: endpoint,
            method: .GET,
            token: token
        )
    }

    func poke(token: String, userId: String) async throws -> PokeResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.poke(userId),
            method: .POST,
            token: token
        )
    }

    func getMatches(token: String) async throws -> MatchesListResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.matches,
            method: .GET,
            token: token
        )
    }

    func getIncomingPokes(token: String) async throws -> IncomingPokesResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.incomingPokes,
            method: .GET,
            token: token
        )
    }
}
