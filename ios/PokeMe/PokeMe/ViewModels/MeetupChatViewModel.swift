import Foundation
import SwiftUI

@MainActor
class MeetupChatViewModel: ObservableObject {
    @Published var messages: [MeetupMessage] = []
    @Published var isSending = false
    @Published var errorMessage: String?

    private var meetupId: String?
    private var currentUserId: String?
    private var pollTimer: Timer?

    func configure(meetupId: String, currentUserId: String) {
        self.meetupId = meetupId
        self.currentUserId = currentUserId
    }

    func fetchMessages(token: String?) async {
        guard let token = token, let meetupId = meetupId else { return }

        do {
            let response = try await MeetupService.shared.getMeetupMessages(token: token, meetupId: meetupId)
            messages = response.messages
            errorMessage = nil
        } catch {
            // Silently fail on poll errors to avoid disrupting UX
        }
    }

    func sendMessage(token: String?, text: String) async {
        guard let token = token, let meetupId = meetupId else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true

        do {
            let response = try await MeetupService.shared.sendMeetupMessage(token: token, meetupId: meetupId, text: trimmed)
            messages.append(response.message)
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    func startPolling(token: String?) {
        stopPolling()
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchMessages(token: token)
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
