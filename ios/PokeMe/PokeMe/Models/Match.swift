import Foundation

struct Match: Codable, Identifiable {
    let id: String
    let partnerId: String
    let partnerName: String
    let partnerSports: [SportEntry]?
    let partnerCollegeYear: String?
    let partnerProfilePicture: String?
    let status: String
    let lastMessage: LastMessage?
    let createdAt: String
}

struct LastMessage: Codable {
    let text: String
    let senderId: String
    let createdAt: String
}

struct MatchesListResponse: Codable {
    let matches: [Match]
}

struct PokeResponse: Codable {
    let status: String
    let message: String
    let match: Match?
}

struct DiscoverResponse: Codable {
    let profiles: [User]
}

struct IncomingPoke: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let createdAt: String
    let fromUser: User
}

struct IncomingPokesResponse: Codable {
    let pokes: [IncomingPoke]
    let count: Int
}

struct ResetResponse: Codable {
    let deletedPokes: Int
    let deletedMatches: Int
}
