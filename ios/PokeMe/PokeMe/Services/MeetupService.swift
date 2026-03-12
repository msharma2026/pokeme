import Foundation

class MeetupService {
    static let shared = MeetupService()

    private init() {}

    func getMeetups(token: String, sport: String? = nil, date: String? = nil) async throws -> MeetupsResponse {
        var endpoint = Constants.Endpoints.meetups
        var params: [String] = []
        if let sport = sport { params.append("sport=\(sport)") }
        if let date = date { params.append("date=\(date)") }
        if !params.isEmpty { endpoint += "?" + params.joined(separator: "&") }

        return try await NetworkService.shared.request(
            endpoint: endpoint,
            method: .GET,
            token: token
        )
    }

    func getMyMeetups(token: String) async throws -> MeetupsResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.myMeetups,
            method: .GET,
            token: token
        )
    }

    func createMeetup(token: String, request body: CreateMeetupRequest) async throws -> MeetupResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.meetups,
            method: .POST,
            body: body,
            token: token
        )
    }

    func joinMeetup(token: String, meetupId: String) async throws -> MeetupResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.joinMeetup(meetupId),
            method: .POST,
            token: token
        )
    }

    func leaveMeetup(token: String, meetupId: String) async throws -> MeetupResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.leaveMeetup(meetupId),
            method: .POST,
            token: token
        )
    }

    func cancelMeetup(token: String, meetupId: String) async throws {
        let _: MeetupDeleteResponse = try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.deleteMeetup(meetupId),
            method: .DELETE,
            token: token
        )
    }

    func getParticipants(token: String, meetupId: String) async throws -> MeetupParticipantsResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.meetupParticipants(meetupId),
            method: .GET,
            token: token
        )
    }

    func getMeetupMessages(token: String, meetupId: String) async throws -> MeetupMessagesResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.meetupMessages(meetupId),
            method: .GET,
            token: token
        )
    }

    func sendMeetupMessage(token: String, meetupId: String, text: String) async throws -> MeetupMessageResponse {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.meetupMessages(meetupId),
            method: .POST,
            body: ["text": text],
            token: token
        )
    }
}

// MARK: - MeetupParticipantsCache
// Avoids re-fetching the participant list every time a card is expanded
// or a detail sheet is opened. Entries expire after 5 minutes.

final class MeetupParticipantsCache {
    static let shared = MeetupParticipantsCache()
    private init() {}

    private var cache: [String: [User]] = [:]
    private var fetchTimes: [String: Date] = [:]
    private let ttl: TimeInterval = 300 // 5 minutes

    func participants(for meetupId: String) -> [User]? {
        guard let time = fetchTimes[meetupId], Date().timeIntervalSince(time) < ttl else { return nil }
        return cache[meetupId]
    }

    func store(_ participants: [User], for meetupId: String) {
        cache[meetupId] = participants
        fetchTimes[meetupId] = Date()
    }

    func invalidate(meetupId: String) {
        cache.removeValue(forKey: meetupId)
        fetchTimes.removeValue(forKey: meetupId)
    }
}
