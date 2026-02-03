import Foundation

@MainActor
class MessageNotificationPoller: ObservableObject {
    private var pollTimer: Timer?
    private var hasLoadedOnce = false
    private var lastPartnerMessageId: String?
    private var currentMatchId: String?
    private var currentPartnerName: String?

    func updateContext(matchId: String?, partnerName: String?) {
        if matchId != currentMatchId {
            currentMatchId = matchId
            currentPartnerName = partnerName
            resetTracking()
        } else {
            currentPartnerName = partnerName
        }
    }

    func startPolling(token: String?, currentUserId: String?) {
        stopPolling()
        guard let token = token, let currentUserId = currentUserId else { return }

        let timer = Timer(timeInterval: 6.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchAndNotify(token: token, currentUserId: currentUserId)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        Task {
            await fetchAndNotify(token: token, currentUserId: currentUserId)
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        resetTracking()
    }

    private func fetchAndNotify(token: String, currentUserId: String) async {
        do {
            let response = try await MessageService.shared.getMessages(token: token)

            if currentMatchId == nil {
                currentMatchId = response.matchId
            } else if response.matchId != currentMatchId {
                currentMatchId = response.matchId
                resetTracking()
            }

            let partnerMessages = response.messages.filter { $0.senderId != currentUserId }
            guard let latestPartnerMessage = partnerMessages.max(by: { $0.createdAt < $1.createdAt }) else {
                hasLoadedOnce = true
                return
            }

            if hasLoadedOnce, latestPartnerMessage.id != lastPartnerMessageId {
                let partnerName = currentPartnerName ?? "Your match"
                NotificationManager.shared.notify(
                    title: "New Message",
                    body: "\(partnerName): \(latestPartnerMessage.text)"
                )
            }

            lastPartnerMessageId = latestPartnerMessage.id
            hasLoadedOnce = true
        } catch {
            // Silent failure for background notifications
        }
    }

    private func resetTracking() {
        hasLoadedOnce = false
        lastPartnerMessageId = nil
    }
}
