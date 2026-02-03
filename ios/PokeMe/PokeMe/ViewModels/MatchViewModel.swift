import Foundation
import SwiftUI

enum MatchState: Equatable {
    case loading
    case matched(Match)
    case waiting
    case disconnected(nextMatchAt: String)
    case error(String)

    static func == (lhs: MatchState, rhs: MatchState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.waiting, .waiting):
            return true
        case (.matched(let m1), .matched(let m2)):
            return m1.id == m2.id
        case (.disconnected(let d1), .disconnected(let d2)):
            return d1 == d2
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

@MainActor
class MatchViewModel: ObservableObject {
    @Published var matchState: MatchState = .loading
    @Published var isLoading = false

    private var pollTimer: Timer?
    private var hasLoadedOnce = false
    private var lastMatchId: String?
    private var lastPartnerPokes: Int?

    func fetchTodayMatch(token: String?) async {
        guard let token = token else {
            matchState = .error("Not authenticated")
            return
        }

        isLoading = true

        do {
            let response = try await MatchService.shared.getTodayMatch(token: token)

            switch response.status {
            case "matched":
                if let match = response.match {
                    handleMatchUpdate(match)
                    matchState = .matched(match)
                } else {
                    matchState = .error("Match data missing")
                }
            case "waiting":
                matchState = .waiting
            case "disconnected":
                matchState = .disconnected(nextMatchAt: response.nextMatchAt ?? "tomorrow")
                resetMatchTracking()
            default:
                matchState = .error("Unknown status")
            }
        } catch let error as NetworkError {
            matchState = .error(error.errorDescription ?? "Unknown error")
        } catch {
            matchState = .error(error.localizedDescription)
        }

        hasLoadedOnce = true
        isLoading = false
    }

    func disconnect(token: String?) async {
        guard let token = token else {
            matchState = .error("Not authenticated")
            return
        }

        isLoading = true

        do {
            let response = try await MatchService.shared.disconnect(token: token)
            matchState = .disconnected(nextMatchAt: response.nextMatchAt)
            resetMatchTracking()
        } catch let error as NetworkError {
            matchState = .error(error.errorDescription ?? "Unknown error")
        } catch {
            matchState = .error(error.localizedDescription)
        }

        isLoading = false
    }

    func poke(token: String?) async {
        guard let token = token else {
            matchState = .error("Not authenticated")
            return
        }

        do {
            let response = try await MatchService.shared.poke(token: token)
            handleMatchUpdate(response.match)
            matchState = .matched(response.match)
        } catch let error as NetworkError {
            matchState = .error(error.errorDescription ?? "Unknown error")
        } catch {
            matchState = .error(error.localizedDescription)
        }
    }

    func startPolling(token: String?) {
        stopPolling()
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshMatch(token: token)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshMatch(token: String?) async {
        guard let token = token else { return }

        do {
            let response = try await MatchService.shared.getTodayMatch(token: token)

            switch response.status {
            case "matched":
                if let match = response.match {
                    handleMatchUpdate(match)
                    matchState = .matched(match)
                }
            case "disconnected":
                matchState = .disconnected(nextMatchAt: response.nextMatchAt ?? "tomorrow")
                resetMatchTracking()
                stopPolling()
            default:
                break
            }
        } catch {
            // Silently fail on refresh - don't update error state
        }
    }

    private func handleMatchUpdate(_ match: Match) {
        defer {
            lastMatchId = match.id
            lastPartnerPokes = match.partnerPokes
            hasLoadedOnce = true
        }

        guard hasLoadedOnce else { return }

        if lastMatchId != match.id {
            NotificationManager.shared.notify(
                title: "New Match!",
                body: "You matched with \(match.partnerName). Say hi!"
            )
            return
        }

        if let previousPokes = lastPartnerPokes,
           match.partnerPokes > previousPokes {
            NotificationManager.shared.notify(
                title: "You got a poke!",
                body: "\(match.partnerName) poked you."
            )
        }
    }

    private func resetMatchTracking() {
        lastMatchId = nil
        lastPartnerPokes = nil
        hasLoadedOnce = false
    }
}
