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
                    matchState = .matched(match)
                } else {
                    matchState = .error("Match data missing")
                }
            case "waiting":
                matchState = .waiting
            case "disconnected":
                matchState = .disconnected(nextMatchAt: response.nextMatchAt ?? "tomorrow")
            default:
                matchState = .error("Unknown status")
            }
        } catch let error as NetworkError {
            matchState = .error(error.errorDescription ?? "Unknown error")
        } catch {
            matchState = .error(error.localizedDescription)
        }

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
        } catch let error as NetworkError {
            matchState = .error(error.errorDescription ?? "Unknown error")
        } catch {
            matchState = .error(error.localizedDescription)
        }

        isLoading = false
    }
}
