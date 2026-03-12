import Foundation
import SwiftUI

@MainActor
class MatchViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var groupChats: [Meetup] = []
    @Published var deletedMatches: [Match] = []
    @Published var deletedMeetups: [Meetup] = []
    @Published var blockedMatches: [Match] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var groupChatUnreadCounts: [String: Int] = [:]

    private var pollTimer: Timer?
    private var meetupPollTimer: Timer?
    private var previousMatchIds: Set<String> = []
    private let seenMatchIdsKey = "seenMatchIds"
    private let hasCompletedInitialMatchSyncKey = "hasCompletedInitialMatchSync"
    private let deletedMatchesKey = "deletedMatchesArchive"
    private let deletedMeetupsKey = "deletedMeetupsArchive"
    private let blockedMatchesKey = "blockedMatchesArchive"
    private var hasCompletedInitialMatchSync: Bool
    private let groupChatLastOpenedKeyPrefix = "groupChatLastOpened_"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "seenMatchIds") ?? []
        previousMatchIds = Set(saved)
        hasCompletedInitialMatchSync = UserDefaults.standard.bool(forKey: hasCompletedInitialMatchSyncKey)
        if let data = UserDefaults.standard.data(forKey: deletedMatchesKey),
           let items = try? JSONDecoder().decode([Match].self, from: data) {
            deletedMatches = items
        }
        if let data = UserDefaults.standard.data(forKey: deletedMeetupsKey),
           let items = try? JSONDecoder().decode([Meetup].self, from: data) {
            deletedMeetups = items
        }
        if let data = UserDefaults.standard.data(forKey: blockedMatchesKey),
           let items = try? JSONDecoder().decode([Match].self, from: data) {
            blockedMatches = items
        }
    }

    private func saveDeletedMatches() {
        guard let data = try? JSONEncoder().encode(deletedMatches) else { return }
        UserDefaults.standard.set(data, forKey: deletedMatchesKey)
    }

    private func saveDeletedMeetups() {
        guard let data = try? JSONEncoder().encode(deletedMeetups) else { return }
        UserDefaults.standard.set(data, forKey: deletedMeetupsKey)
    }

    private func saveBlockedMatches() {
        guard let data = try? JSONEncoder().encode(blockedMatches) else { return }
        UserDefaults.standard.set(data, forKey: blockedMatchesKey)
    }

    func fetchMatches(token: String?) async {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = matches.isEmpty && groupChats.isEmpty

        do {
            let response = try await MatchService.shared.getMatches(token: token)

            let currentMatchIds = Set(response.matches.map { $0.id })
            if hasCompletedInitialMatchSync {
                let newMatches = response.matches.filter {
                    shouldNotifyForNewMatch($0, previousMatchIds: previousMatchIds)
                }

                if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                    for match in newMatches {
                        NotificationManager.shared.notify(
                            title: "It's a Match!",
                            body: "You and \(match.partnerName) both want to play! Start chatting.",
                            identifier: "match-\(match.id)"
                        )
                    }
                }
            }

            previousMatchIds = currentMatchIds
            UserDefaults.standard.set(Array(currentMatchIds), forKey: seenMatchIdsKey)
            hasCompletedInitialMatchSync = true
            UserDefaults.standard.set(true, forKey: hasCompletedInitialMatchSyncKey)

            matches = response.matches
            RelationshipStatusCache.shared.populateMatches(response.matches)
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func fetchGroupChats(token: String?) async {
        guard let token = token else { return }
        do {
            let meetupResponse = try await MeetupService.shared.getMyMeetups(token: token)
            groupChats = meetupResponse.meetups
            await updateGroupChatUnreadCounts(token: token)
        } catch {
            // Keep existing groupChats on transient failures so stale data stays visible
        }
    }

    func markGroupChatRead(meetupId: String) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        UserDefaults.standard.set(iso.string(from: Date()), forKey: groupChatLastOpenedKeyPrefix + meetupId)
        groupChatUnreadCounts[meetupId] = 0
    }

    private func updateGroupChatUnreadCounts(token: String) async {
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        for meetup in groupChats {
            guard let response = try? await MeetupService.shared.getMeetupMessages(token: token, meetupId: meetup.id) else { continue }

            let lastOpenedStr = UserDefaults.standard.string(forKey: groupChatLastOpenedKeyPrefix + meetup.id)
            let lastOpened: Date
            if let str = lastOpenedStr,
               let date = isoFull.date(from: str) ?? isoBasic.date(from: str) {
                lastOpened = date
            } else {
                lastOpened = .distantPast
            }

            let unread = response.messages.filter { msg in
                let date = isoFull.date(from: msg.createdAt) ?? isoBasic.date(from: msg.createdAt)
                return (date ?? .distantPast) > lastOpened
            }.count
            groupChatUnreadCounts[meetup.id] = unread
        }
    }

    func deleteMatch(token: String?, matchId: String) async {
        if let match = matches.first(where: { $0.id == matchId }) {
            if !deletedMatches.contains(where: { $0.id == matchId }) {
                deletedMatches.insert(match, at: 0)
                saveDeletedMatches()
            }
        }
        matches.removeAll { $0.id == matchId }
        guard let token = token else { return }
        try? await MatchService.shared.deleteMatch(token: token, matchId: matchId)
    }

    func leaveMeetup(token: String?, meetupId: String) async {
        if let meetup = groupChats.first(where: { $0.id == meetupId }) {
            if !deletedMeetups.contains(where: { $0.id == meetupId }) {
                deletedMeetups.insert(meetup, at: 0)
                saveDeletedMeetups()
            }
        }
        groupChats.removeAll { $0.id == meetupId }
        guard let token = token else { return }
        try? await MeetupService.shared.leaveMeetup(token: token, meetupId: meetupId)
    }

    func permanentlyDeleteMatch(id: String) {
        deletedMatches.removeAll { $0.id == id }
        saveDeletedMatches()
    }

    func permanentlyDeleteMeetup(id: String) {
        deletedMeetups.removeAll { $0.id == id }
        saveDeletedMeetups()
    }

    func blockMatch(token: String?, matchId: String) async {
        if let match = matches.first(where: { $0.id == matchId }) {
            if !blockedMatches.contains(where: { $0.id == matchId }) {
                blockedMatches.insert(match, at: 0)
                saveBlockedMatches()
            }
        }
        matches.removeAll { $0.id == matchId }
        deletedMatches.removeAll { $0.id == matchId }
        saveDeletedMatches()
        guard let token = token else { return }
        try? await MatchService.shared.deleteMatch(token: token, matchId: matchId)
    }

    func unblockMatch(id: String) {
        blockedMatches.removeAll { $0.id == id }
        saveBlockedMatches()
    }

    func restoreMatch(id: String) {
        guard let match = deletedMatches.first(where: { $0.id == id }) else { return }
        deletedMatches.removeAll { $0.id == id }
        saveDeletedMatches()
        if !matches.contains(where: { $0.id == id }) {
            matches.insert(match, at: 0)
        }
    }

    func restoreMeetup(id: String) {
        guard let meetup = deletedMeetups.first(where: { $0.id == id }) else { return }
        deletedMeetups.removeAll { $0.id == id }
        saveDeletedMeetups()
        if !groupChats.contains(where: { $0.id == id }) {
            groupChats.insert(meetup, at: 0)
        }
    }

    func clearTrash() {
        deletedMatches = []
        deletedMeetups = []
        blockedMatches = []
        saveDeletedMatches()
        saveDeletedMeetups()
        saveBlockedMatches()
    }

    func prefetchAllMessages(token: String?, currentUserId: String?) async {
        guard let token = token, let currentUserId = currentUserId else { return }
        await withTaskGroup(of: Void.self) { group in
            for match in matches {
                let matchId = match.id
                group.addTask {
                    // Skip if already cached
                    guard MessageCache.shared.getMessages(for: matchId) == nil else { return }
                    do {
                        let response = try await MessageService.shared.getMessages(token: token, matchId: matchId, since: nil)
                        var msgs = response.messages
                        for i in 0..<msgs.count {
                            msgs[i].isFromCurrentUser = msgs[i].senderId == currentUserId
                        }
                        let timestamp = msgs.compactMap { $0.createdAt }.max()
                        MessageCache.shared.update(matchId: matchId, messages: msgs, timestamp: timestamp)
                    } catch {}
                }
            }
        }
    }

    func startPolling(token: String?) {
        stopPolling()
        let matchTimer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchMatches(token: token)
            }
        }
        RunLoop.main.add(matchTimer, forMode: .common)
        pollTimer = matchTimer

        // Group chats change rarely — poll at a much lower rate
        let meetupTimer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchGroupChats(token: token)
            }
        }
        RunLoop.main.add(meetupTimer, forMode: .common)
        meetupPollTimer = meetupTimer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        meetupPollTimer?.invalidate()
        meetupPollTimer = nil
    }

    static func shouldNotifyForNewMatch(_ match: Match, previousMatchIds: Set<String>) -> Bool {
        guard !previousMatchIds.contains(match.id) else { return false }
        return match.lastMessage == nil
    }

    private func shouldNotifyForNewMatch(_ match: Match, previousMatchIds: Set<String>) -> Bool {
        Self.shouldNotifyForNewMatch(match, previousMatchIds: previousMatchIds)
    }
}
