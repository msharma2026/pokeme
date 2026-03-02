import Foundation
import SwiftUI

@MainActor
class MatchViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var groupChats: [Meetup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var pollTimer: Timer?
    private var previousMatchIds: Set<String> = []
    private let seenMatchIdsKey = "seenMatchIds"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "seenMatchIds") ?? []
        previousMatchIds = Set(saved)
    }

    func fetchMatches(token: String?) async {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = matches.isEmpty && groupChats.isEmpty

        do {
            let response = try await MatchService.shared.getMatches(token: token)

            // Detect new matches — notifies the OTHER user when a mutual poke creates a match
            let currentMatchIds = Set(response.matches.map { $0.id })
            let newMatches = response.matches.filter { !previousMatchIds.contains($0.id) }
            for match in newMatches {
                NotificationManager.shared.notify(
                    title: "It's a Match!",
                    body: "You and \(match.partnerName) both want to play! Start chatting.",
                    identifier: "match-\(match.id)"
                )
            }
            previousMatchIds = currentMatchIds
            UserDefaults.standard.set(Array(currentMatchIds), forKey: seenMatchIdsKey)

            matches = response.matches
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        // Fetch meetup group chats (meetups with 2+ participants the user is in)
        if let meetupResponse = try? await MeetupService.shared.getMyMeetups(token: token) {
            groupChats = meetupResponse.meetups.filter { $0.participantCount >= 2 }
        }

        isLoading = false
    }

    func startPolling(token: String?) {
        stopPolling()
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchMatches(token: token)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
