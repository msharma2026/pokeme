import Foundation
import SwiftUI

@MainActor
class MeetupViewModel: ObservableObject {
    @Published var meetups: [Meetup] = []
    @Published var myMeetups: [Meetup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sportFilter: String?

    func fetchMeetups(token: String?) async {
        guard let token = token else { return }
        isLoading = meetups.isEmpty

        do {
            let response = try await MeetupService.shared.getMeetups(token: token, sport: sportFilter)
            meetups = response.meetups
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load meetups"
        }

        isLoading = false
    }

    func fetchMyMeetups(token: String?) async {
        guard let token = token else { return }

        do {
            let response = try await MeetupService.shared.getMyMeetups(token: token)
            myMeetups = response.meetups
        } catch {}
    }

    func createMeetup(token: String?, request body: CreateMeetupRequest) async -> Bool {
        guard let token = token else { return false }

        do {
            let response = try await MeetupService.shared.createMeetup(token: token, request: body)
            meetups.insert(response.meetup, at: 0)
            return true
        } catch {
            errorMessage = "Failed to create meetup"
            return false
        }
    }

    func joinMeetup(token: String?, meetupId: String) async {
        guard let token = token else { return }

        do {
            let response = try await MeetupService.shared.joinMeetup(token: token, meetupId: meetupId)
            if let index = meetups.firstIndex(where: { $0.id == meetupId }) {
                meetups[index] = response.meetup
            }
        } catch {
            errorMessage = "Failed to join meetup"
        }
    }

    func leaveMeetup(token: String?, meetupId: String) async {
        guard let token = token else { return }

        do {
            let response = try await MeetupService.shared.leaveMeetup(token: token, meetupId: meetupId)
            if let index = meetups.firstIndex(where: { $0.id == meetupId }) {
                meetups[index] = response.meetup
            }
        } catch {
            errorMessage = "Failed to leave meetup"
        }
    }

    func cancelMeetup(token: String?, meetupId: String) async {
        guard let token = token else { return }

        do {
            try await MeetupService.shared.cancelMeetup(token: token, meetupId: meetupId)
            meetups.removeAll { $0.id == meetupId }
        } catch {
            errorMessage = "Failed to cancel meetup"
        }
    }
}
