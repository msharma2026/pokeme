import Foundation
import SwiftUI

@MainActor
class MatchViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var pollTimer: Timer?
    private var hasLoadedOnce = false
    private var lastMatchId: String?
    private var lastPartnerPokes: Int?

    func fetchMatches(token: String?) async {
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
            errorMessage = "Not authenticated"
            return
        }

        isLoading = matches.isEmpty

        do {
            let response = try await MatchService.shared.getMatches(token: token)
            matches = response.matches
            errorMessage = nil
            let response = try await MatchService.shared.disconnect(token: token)
            matchState = .disconnected(nextMatchAt: response.nextMatchAt)
            resetMatchTracking()
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
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
