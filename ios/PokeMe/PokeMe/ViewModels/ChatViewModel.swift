import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var partnerIsTyping = false

    static let allowedReactions = ["👍", "❤️", "😂", "😮", "😢"]

    private var currentUserId: String?
    private var pollTimer: Timer?

    // Typing indicator debounce
    private var lastTypingSentAt: Date?
    private var typingStopTimer: Timer?
    private let typingDebounceInterval: TimeInterval = 2.0
    private let typingAutoStopInterval: TimeInterval = 5.0  // Stop typing after 5s of no input

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
            partnerIsTyping = response.partnerIsTyping ?? false
            errorMessage = nil

            // Mark unread messages as read
            await markUnreadMessagesAsRead(token: token)
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

            // Stop typing indicator after sending
            await stopTyping(token: token)
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

    // MARK: - Reactions

    func addReaction(token: String?, messageId: String, emoji: String) async {
        guard let token = token, let currentUserId = currentUserId else { return }

        // Optimistically update UI
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updatedMessage = messages[index]
            var reactions = updatedMessage.reactions ?? []
            reactions.append(Reaction(emoji: emoji, userId: currentUserId, createdAt: ISO8601DateFormatter().string(from: Date())))
            updatedMessage.reactions = reactions
            messages[index] = updatedMessage
        }

        do {
            _ = try await MessageService.shared.addReaction(token: token, messageId: messageId, emoji: emoji)
            // Don't immediately refetch - let polling handle sync
            // This preserves the optimistic update
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            // Revert on error by refetching
            await fetchMessages(token: token)
        } catch {
            errorMessage = error.localizedDescription
            await fetchMessages(token: token)
        }
    }

    func removeReaction(token: String?, messageId: String, emoji: String) async {
        guard let token = token, let currentUserId = currentUserId else { return }

        // Optimistically update UI
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updatedMessage = messages[index]
            var reactions = updatedMessage.reactions ?? []
            reactions.removeAll { $0.userId == currentUserId && $0.emoji == emoji }
            updatedMessage.reactions = reactions
            messages[index] = updatedMessage
        }

        do {
            try await MessageService.shared.removeReaction(token: token, messageId: messageId, emoji: emoji)
            // Don't immediately refetch - let polling handle sync
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            await fetchMessages(token: token)
        } catch {
            errorMessage = error.localizedDescription
            await fetchMessages(token: token)
        }
    }

    /// Toggle reaction - add if not present, remove if user already reacted with this emoji
    func toggleReaction(token: String?, messageId: String, emoji: String) async {
        guard let token = token, let currentUserId = currentUserId else { return }

        // Find the message and check if user already reacted
        if let message = messages.first(where: { $0.id == messageId }),
           let reactions = message.reactions,
           reactions.contains(where: { $0.userId == currentUserId && $0.emoji == emoji }) {
            await removeReaction(token: token, messageId: messageId, emoji: emoji)
        } else {
            await addReaction(token: token, messageId: messageId, emoji: emoji)
        }
    }

    // MARK: - Read Receipts

    func markUnreadMessagesAsRead(token: String) async {
        guard let currentUserId = currentUserId else { return }

        // Find messages not sent by current user and not yet read by current user
        let unreadMessageIds = messages
            .filter { msg in
                msg.senderId != currentUserId &&
                !(msg.readBy ?? []).contains(currentUserId)
            }
            .map { $0.id }

        guard !unreadMessageIds.isEmpty else { return }

        do {
            _ = try await MessageService.shared.markMessagesRead(token: token, messageIds: unreadMessageIds)
            // Update local state to reflect read status
            for i in 0..<messages.count {
                if unreadMessageIds.contains(messages[i].id) {
                    var readBy = messages[i].readBy ?? []
                    if !readBy.contains(currentUserId) {
                        readBy.append(currentUserId)
                        messages[i].readBy = readBy
                    }
                }
            }
        } catch {
            // Silent failure for read receipts - not critical
        }
    }

    // MARK: - Typing Indicators

    /// Call this when the user is typing. Debounced to avoid excessive API calls.
    func userIsTyping(token: String?) {
        guard let token = token else { return }

        // Reset the auto-stop timer
        typingStopTimer?.invalidate()
        typingStopTimer = Timer.scheduledTimer(withTimeInterval: typingAutoStopInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.stopTyping(token: token)
            }
        }

        // Debounce: only send if we haven't sent recently
        let now = Date()
        if let lastSent = lastTypingSentAt, now.timeIntervalSince(lastSent) < typingDebounceInterval {
            return
        }

        lastTypingSentAt = now

        Task {
            do {
                _ = try await MessageService.shared.updateTyping(token: token, isTyping: true)
            } catch {
                // Silent failure for typing indicator
            }
        }
    }

    /// Call this to stop the typing indicator.
    func stopTyping(token: String?) async {
        typingStopTimer?.invalidate()
        typingStopTimer = nil
        lastTypingSentAt = nil

        guard let token = token else { return }

        do {
            _ = try await MessageService.shared.updateTyping(token: token, isTyping: false)
        } catch {
            // Silent failure for typing indicator
        }
    }
}
