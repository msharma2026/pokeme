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

    func deleteMatch(token: String, matchId: String) async throws {
        let _: ResetResponse = try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.deleteMatch(matchId),
            method: .DELETE,
            token: token
        )
    }

    func resetTestData(token: String) async throws -> ResetResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.adminReset,
            method: .POST,
            token: token
        )
    }
}

// MARK: - RelationshipStatusCache
// Tracks poke and match status in-memory so ParticipantProfileSheet
// never needs to make an API call just to determine the button state.

final class RelationshipStatusCache {
    static let shared = RelationshipStatusCache()
    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: pokedKey) ?? []
        _pokedIds = Set(saved)
    }

    private let pokedKey = "pokedUserIds"
    private var _pokedIds: Set<String> = []
    // partnerId → (matchId, partnerName)
    private var _matched: [String: (matchId: String, partnerName: String)] = [:]

    // MARK: Reads
    func isPoked(_ userId: String) -> Bool { _pokedIds.contains(userId) }
    func matchInfo(for userId: String) -> (matchId: String, partnerName: String)? { _matched[userId] }

    // MARK: Writes
    func markPoked(_ userId: String) {
        _pokedIds.insert(userId)
        var saved = UserDefaults.standard.stringArray(forKey: pokedKey) ?? []
        if !saved.contains(userId) {
            saved.append(userId)
            UserDefaults.standard.set(saved, forKey: pokedKey)
        }
    }

    func populateMatches(_ matches: [Match]) {
        for m in matches {
            _matched[m.partnerId] = (m.id, m.partnerName)
            _pokedIds.insert(m.partnerId)
        }
    }

    func populatePokedIds(_ ids: [String]) {
        for id in ids { _pokedIds.insert(id) }
        var saved = Set(UserDefaults.standard.stringArray(forKey: pokedKey) ?? [])
        ids.forEach { saved.insert($0) }
        UserDefaults.standard.set(Array(saved), forKey: pokedKey)
    }
}
