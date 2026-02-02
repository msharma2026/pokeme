import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    private var currentUserId: String?
    private var pollTimer: Timer?

    func setCurrentUser(id: String) {
        self.currentUserId = id
    }

    func fetchMessages(token: String?) async {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = messages.isEmpty

        do {
            let response = try await MessageService.shared.getMessages(token: token)
            var updatedMessages = response.messages
            // Mark which messages are from current user
            for i in 0..<updatedMessages.count {
                updatedMessages[i].isFromCurrentUser = updatedMessages[i].senderId == currentUserId
            }
            messages = updatedMessages
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendMessage(token: String?, text: String) async -> Bool {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return false
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }

        isSending = true

        do {
            let response = try await MessageService.shared.sendMessage(token: token, text: trimmedText)
            var newMessage = response.message
            newMessage.isFromCurrentUser = true
            messages.append(newMessage)
            isSending = false
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            isSending = false
            return false
        } catch {
            errorMessage = error.localizedDescription
            isSending = false
            return false
        }
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
