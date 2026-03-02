import Foundation
import SwiftUI
import UserNotifications

@MainActor
class PokesViewModel: ObservableObject {
    @Published var incomingPokes: [IncomingPoke] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pokeCount: Int = 0
    @Published var showMatchAlert = false
    @Published var matchedUser: User?

    private var pollTimer: Timer?
    private var previousPokeIds: Set<String> = []
    private let seenPokeIdsKey = "seenPokeIds"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "seenPokeIds") ?? []
        previousPokeIds = Set(saved)
    }

    func fetchIncomingPokes(token: String?) async {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = incomingPokes.isEmpty

        do {
            let response = try await MatchService.shared.getIncomingPokes(token: token)

            // Detect new pokes — compare against persisted seen IDs so
            // notifications fire even on the first poll after app launch.
            let newPokeIds = Set(response.pokes.map { $0.id })
            let brandNewPokes = response.pokes.filter { !previousPokeIds.contains($0.id) }
            for poke in brandNewPokes {
                sendLocalNotification(
                    title: "New Poke!",
                    body: "\(poke.fromUser.displayName) poked you! Poke back to match."
                )
            }
            previousPokeIds = newPokeIds
            UserDefaults.standard.set(Array(newPokeIds), forKey: seenPokeIdsKey)

            incomingPokes = response.pokes
            pokeCount = response.count
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func pokeBack(token: String?, userId: String) async {
        guard let token = token else { return }

        do {
            let response = try await MatchService.shared.poke(token: token, userId: userId)

            if response.status == "matched" {
                matchedUser = incomingPokes.first(where: { $0.fromUserId == userId })?.fromUser
                showMatchAlert = true

                sendLocalNotification(
                    title: "It's a Match!",
                    body: "You and \(matchedUser?.displayName ?? "someone") matched! Start chatting now."
                )
            }

            // Remove this poke from the list
            incomingPokes.removeAll { $0.fromUserId == userId }
            pokeCount = incomingPokes.count
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startPolling(token: String?) {
        stopPolling()
        let timer = Timer(timeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchIncomingPokes(token: token)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func sendLocalNotification(title: String, body: String) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
