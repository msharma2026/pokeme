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
    private var matchId: String?
    private var pollTimer: Timer?
    private var latestMessageTimestamp: String?

    // Typing indicator debounce
    private var lastTypingSentAt: Date?
    private var typingStopTimer: Timer?
    private let typingDebounceInterval: TimeInterval = 2.0
    private let typingAutoStopInterval: TimeInterval = 5.0

    func configure(currentUserId: String, matchId: String) {
        self.currentUserId = currentUserId
        self.matchId = matchId
    }

    func fetchMessages(token: String?) async {
        guard let token = token, let matchId = matchId else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = messages.isEmpty
        let since = latestMessageTimestamp

        do {
            let response = try await MessageService.shared.getMessages(token: token, matchId: matchId, since: since)
            partnerIsTyping = response.partnerIsTyping ?? false
            errorMessage = nil

            if since == nil {
                // Initial load — replace all messages
                var all = response.messages
                for i in 0..<all.count {
                    all[i].isFromCurrentUser = all[i].senderId == currentUserId
                }
                messages = all
            } else if !response.messages.isEmpty {
                // Poll — append only new messages
                var newMsgs = response.messages
                for i in 0..<newMsgs.count {
                    newMsgs[i].isFromCurrentUser = newMsgs[i].senderId == currentUserId
                }
                let existingIds = Set(messages.map { $0.id })
                messages.append(contentsOf: newMsgs.filter { !existingIds.contains($0.id) })
            }

            // Track the latest timestamp for the next poll
            latestMessageTimestamp = messages.compactMap { $0.createdAt }.max() ?? latestMessageTimestamp

            await markUnreadMessagesAsRead(token: token)
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendMessage(token: String?, text: String) async -> Bool {
        guard let token = token, let matchId = matchId else {
            errorMessage = "Not authenticated"
            return false
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }

        isSending = true

        do {
            let response = try await MessageService.shared.sendMessage(token: token, matchId: matchId, text: trimmedText)
            var newMessage = response.message
            newMessage.isFromCurrentUser = true
            messages.append(newMessage)
            isSending = false

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
        guard let token = token, let matchId = matchId, let currentUserId = currentUserId else { return }

        // Optimistically update UI
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updatedMessage = messages[index]
            var reactions = updatedMessage.reactions ?? []
            reactions.append(Reaction(emoji: emoji, userId: currentUserId, createdAt: ISO8601DateFormatter().string(from: Date())))
            updatedMessage.reactions = reactions
            messages[index] = updatedMessage
        }

        do {
            _ = try await MessageService.shared.addReaction(token: token, matchId: matchId, messageId: messageId, emoji: emoji)
        } catch {
            await fetchMessages(token: token)
        }
    }

    func removeReaction(token: String?, messageId: String, emoji: String) async {
        guard let token = token, let matchId = matchId, let currentUserId = currentUserId else { return }

        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updatedMessage = messages[index]
            var reactions = updatedMessage.reactions ?? []
            reactions.removeAll { $0.userId == currentUserId && $0.emoji == emoji }
            updatedMessage.reactions = reactions
            messages[index] = updatedMessage
        }

        do {
            try await MessageService.shared.removeReaction(token: token, matchId: matchId, messageId: messageId, emoji: emoji)
        } catch {
            await fetchMessages(token: token)
        }
    }

    func toggleReaction(token: String?, messageId: String, emoji: String) async {
        guard let currentUserId = currentUserId else { return }

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
        guard let currentUserId = currentUserId, let matchId = matchId else { return }

        let unreadMessageIds = messages
            .filter { $0.senderId != currentUserId && !(($0.readBy ?? []).contains(currentUserId)) }
            .map { $0.id }

        guard !unreadMessageIds.isEmpty else { return }

        do {
            _ = try await MessageService.shared.markMessagesRead(token: token, matchId: matchId, messageIds: unreadMessageIds)
            for i in 0..<messages.count {
                if unreadMessageIds.contains(messages[i].id) {
                    var readBy = messages[i].readBy ?? []
                    if !readBy.contains(currentUserId) {
                        readBy.append(currentUserId)
                        messages[i].readBy = readBy
                    }
                }
            }
        } catch {}
    }

    // MARK: - Sessions

    func respondToSession(token: String?, sessionId: String, action: String) async {
        guard let token = token, let matchId = matchId else { return }

        do {
            _ = try await MessageService.shared.updateSession(
                token: token,
                matchId: matchId,
                sessionId: sessionId,
                action: action
            )
            await fetchMessages(token: token)
        } catch {}
    }

    // MARK: - Typing Indicators

    func userIsTyping(token: String?) {
        guard let token = token, let matchId = matchId else { return }

        typingStopTimer?.invalidate()
        typingStopTimer = Timer.scheduledTimer(withTimeInterval: typingAutoStopInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.stopTyping(token: token)
            }
        }

        let now = Date()
        if let lastSent = lastTypingSentAt, now.timeIntervalSince(lastSent) < typingDebounceInterval {
            return
        }

        lastTypingSentAt = now

        Task {
            do {
                _ = try await MessageService.shared.updateTyping(token: token, matchId: matchId, isTyping: true)
            } catch {}
        }
    }

    func stopTyping(token: String?) async {
        typingStopTimer?.invalidate()
        typingStopTimer = nil
        lastTypingSentAt = nil

        guard let token = token, let matchId = matchId else { return }

        do {
            _ = try await MessageService.shared.updateTyping(token: token, matchId: matchId, isTyping: false)
        } catch {}
    }
}
