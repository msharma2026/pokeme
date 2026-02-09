import Foundation
import SwiftUI
import UserNotifications

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var profiles: [User] = []
    @Published var currentIndex = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showMatchAlert = false
    @Published var matchedUser: User?
    @Published var matchedMatch: Match?
    @Published var selectedSport: String?

    var currentProfile: User? {
        guard currentIndex < profiles.count else { return nil }
        return profiles[currentIndex]
    }

    var hasMoreProfiles: Bool {
        currentIndex < profiles.count
    }

    func fetchProfiles(token: String?) async {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await MatchService.shared.discover(token: token, sport: selectedSport)
            profiles = response.profiles
            currentIndex = 0
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func pokeCurrentProfile(token: String?) async {
        guard let token = token, let profile = currentProfile else { return }

        do {
            let response = try await MatchService.shared.poke(token: token, userId: profile.id)

            if response.status == "matched" {
                matchedUser = profile
                matchedMatch = response.match
                showMatchAlert = true

                if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                    let content = UNMutableNotificationContent()
                    content.title = "It's a Match!"
                    content.body = "You and \(profile.displayName) both want to play!"
                    content.sound = .default
                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString, content: content, trigger: nil
                    )
                    try? await UNUserNotificationCenter.current().add(request)
                }
            }

            // Move to next profile
            currentIndex += 1
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skipCurrentProfile() {
        currentIndex += 1
    }
}
