import Foundation

struct Session: Codable, Identifiable {
    let id: String
    let matchId: String
    let proposerId: String
    let responderId: String
    let sport: String
    let day: String
    let startHour: Int
    let endHour: Int
    let location: String?
    let status: String  // "pending", "accepted", "declined"
    let createdAt: String
    let updatedAt: String?
}

struct SharedSport: Codable {
    let sport: String
    let userLevel: String
    let partnerLevel: String
}

struct CompatibleTimesResponse: Codable {
    let compatibleTimes: [String: [String]]
    let sharedSports: [SharedSport]
}

struct CreateSessionRequest: Codable {
    let sport: String
    let day: String
    let startHour: Int
    let endHour: Int
    let location: String
}

struct SessionResponse: Codable {
    let session: Session
}

struct SessionsListResponse: Codable {
    let sessions: [Session]
}

struct UpdateSessionRequest: Codable {
    let action: String  // "accept" or "decline"
}
