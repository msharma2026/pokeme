import Foundation

struct Meetup: Codable, Identifiable {
    let id: String
    let hostId: String
    let hostName: String
    let sport: String
    let title: String
    let description: String?
    let date: String
    let time: String
    let location: String?
    let skillLevels: [String]?
    let playerLimit: Int?
    let participants: [String]?
    let status: String
    let createdAt: String

    var participantCount: Int { participants?.count ?? 0 }
    var isFull: Bool { participantCount >= (playerLimit ?? 10) }
}

struct MeetupsResponse: Codable {
    let meetups: [Meetup]
}

struct MeetupResponse: Codable {
    let meetup: Meetup
}

struct CreateMeetupRequest: Codable {
    let sport: String
    let title: String
    let description: String
    let date: String
    let time: String
    let location: String
    let skillLevels: [String]
    let playerLimit: Int
}

struct MeetupDeleteResponse: Codable {
    let message: String
}
