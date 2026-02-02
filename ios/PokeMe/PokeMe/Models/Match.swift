import Foundation

struct Match: Codable, Identifiable {
    let id: String
    let date: String
    let partnerId: String
    let partnerName: String
    let partnerMajor: String?
    let status: String
    let myPokes: Int
    let partnerPokes: Int
    let createdAt: String
}

struct MatchResponse: Codable {
    let match: Match?
    let status: String
    let message: String?
    let nextMatchAt: String?
}

struct DisconnectResponse: Codable {
    let message: String
    let nextMatchAt: String
}

struct PokeResponse: Codable {
    let match: Match
    let message: String
}
