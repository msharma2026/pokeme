import Foundation
import SwiftUI
import UserNotifications

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var profiles: [User] = []
    @Published var pokedIds: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showMatchAlert = false
    @Published var matchedUser: User?
    @Published var matchedMatch: Match?
    @Published var selectedSport: String?

    func fetchProfiles(token: String?, currentUser: User? = nil) async {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var viewer = currentUser
            if viewer == nil {
                viewer = try? await AuthService.shared.getMe(token: token)
            }

            let response = try await MatchService.shared.discover(token: token, sport: selectedSport)
            let enrichedProfiles = enrichProfilesWithRecommendations(response.profiles, viewer: viewer)
            profiles = enrichedProfiles.sorted {
                ($0.recommendationScore ?? 0) > ($1.recommendationScore ?? 0)
            }
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func enrichProfilesWithRecommendations(_ profiles: [User], viewer: User?) -> [User] {
        guard let viewer else { return profiles }

        return profiles.map { profile in
            if profile.recommendationScore != nil {
                return profile
            }

            var mutable = profile
            let recommendation = scoreCompatibility(viewer: viewer, candidate: profile)
            mutable.recommendationScore = recommendation.score
            mutable.recommendationReasons = recommendation.reasons
            mutable.recommendationBreakdown = recommendation.breakdown
            return mutable
        }
    }

    private func scoreCompatibility(viewer: User, candidate: User) -> (score: Double, reasons: [String], breakdown: [String: Double]) {
        let sportsScoreBundle = sportsSimilarity(viewer, candidate)
        let availabilityScoreBundle = availabilitySimilarity(viewer, candidate)
        let yearScore = collegeYearSimilarity(viewer.collegeYear, candidate.collegeYear)
        let majorBioScoreBundle = majorBioSimilarity(viewer, candidate)

        let score = round(
            (
                (sportsScoreBundle.score * 0.55) +
                (availabilityScoreBundle.score * 0.20) +
                (yearScore * 0.10) +
                (majorBioScoreBundle.score * 0.15)
            ) * 100
        )

        var reasons: [String] = []
        if !sportsScoreBundle.sharedSports.isEmpty {
            reasons.append("Shared sports: \(sportsScoreBundle.sharedSports.prefix(3).joined(separator: ", "))")
        }
        if availabilityScoreBundle.overlaps > 0 {
            reasons.append("Overlapping availability windows")
        }
        if yearScore >= 0.65 {
            reasons.append("Similar college year")
        }
        if majorBioScoreBundle.sameMajor {
            reasons.append("Same major")
        }
        if reasons.isEmpty {
            reasons.append("Recommended from overall profile compatibility")
        }

        return (
            score: score,
            reasons: reasons,
            breakdown: [
                "sports": round(sportsScoreBundle.score * 100),
                "availability": round(availabilityScoreBundle.score * 100),
                "collegeYear": round(yearScore * 100),
                "majorBio": round(majorBioScoreBundle.score * 100),
            ]
        )
    }

    private func sportsSimilarity(_ viewer: User, _ candidate: User) -> (score: Double, sharedSports: [String]) {
        let viewerSports = sportsMap(viewer.sports)
        let candidateSports = sportsMap(candidate.sports)

        guard !viewerSports.isEmpty, !candidateSports.isEmpty else {
            return (0, [])
        }

        let shared = Array(Set(viewerSports.keys).intersection(candidateSports.keys)).sorted()
        guard !shared.isEmpty else {
            return (0, [])
        }

        let coverage = Double(shared.count) / Double(max(viewerSports.count, candidateSports.count))
        let alignment = shared.reduce(0.0) { acc, sport in
            let gap = abs((viewerSports[sport] ?? 2) - (candidateSports[sport] ?? 2))
            return acc + max(0.0, 1.0 - (0.25 * Double(gap)))
        } / Double(shared.count)

        let score = min(1.0, (0.7 * coverage) + (0.3 * alignment))
        return (score, shared)
    }

    private func availabilitySimilarity(_ viewer: User, _ candidate: User) -> (score: Double, overlaps: Int) {
        let viewerSlots = availabilitySlots(viewer.availability)
        let candidateSlots = availabilitySlots(candidate.availability)
        guard !viewerSlots.isEmpty, !candidateSlots.isEmpty else {
            return (0, 0)
        }
        let intersection = viewerSlots.intersection(candidateSlots)
        let union = viewerSlots.union(candidateSlots)
        guard !union.isEmpty else { return (0, 0) }
        return (Double(intersection.count) / Double(union.count), intersection.count)
    }

    private func collegeYearSimilarity(_ viewerYear: String?, _ candidateYear: String?) -> Double {
        let order = ["freshman", "sophomore", "junior", "senior", "graduate"]
        guard
            let v = viewerYear?.lowercased(),
            let c = candidateYear?.lowercased(),
            let vi = order.firstIndex(of: v),
            let ci = order.firstIndex(of: c)
        else {
            return 0
        }
        let distance = abs(vi - ci)
        return max(0.0, 1.0 - (0.35 * Double(distance)))
    }

    private func majorBioSimilarity(_ viewer: User, _ candidate: User) -> (score: Double, sameMajor: Bool) {
        let viewerMajor = viewer.major?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let candidateMajor = candidate.major?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let sameMajor = !viewerMajor.isEmpty && viewerMajor == candidateMajor

        let viewerTokens = textTokens("\(viewer.major ?? "") \(viewer.bio ?? "")")
        let candidateTokens = textTokens("\(candidate.major ?? "") \(candidate.bio ?? "")")
        let textSimilarity: Double
        if viewerTokens.isEmpty || candidateTokens.isEmpty {
            textSimilarity = 0
        } else {
            let intersection = viewerTokens.intersection(candidateTokens)
            let union = viewerTokens.union(candidateTokens)
            textSimilarity = union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
        }

        let majorScore = sameMajor ? 1.0 : 0.0
        let score = min(1.0, (0.6 * majorScore) + (0.4 * textSimilarity))
        return (score, sameMajor)
    }

    private func sportsMap(_ sports: [SportEntry]?) -> [String: Int] {
        guard let sports else { return [:] }
        return sports.reduce(into: [String: Int]()) { map, sport in
            let key = sport.sport.lowercased()
            map[key] = skillValue(sport.skillLevel)
        }
    }

    private func skillValue(_ skillLevel: String) -> Int {
        switch skillLevel.lowercased() {
        case "beginner": return 1
        case "intermediate": return 2
        case "advanced": return 3
        default: return 2
        }
    }

    private func availabilitySlots(_ availability: [String: [String]]?) -> Set<String> {
        guard let availability else { return [] }
        var slots = Set<String>()
        for (day, times) in availability {
            for time in times {
                slots.insert("\(day.lowercased()):\(time.lowercased())")
            }
        }
        return slots
    }

    private func textTokens(_ text: String) -> Set<String> {
        let stopwords: Set<String> = [
            "a", "an", "and", "are", "as", "at", "be", "for", "from", "i", "in", "is",
            "it", "my", "of", "on", "or", "our", "that", "the", "their", "to", "we",
            "with", "you", "your"
        ]
        let lowered = text.lowercased()
        let parts = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return Set(parts.filter { $0.count > 1 && !stopwords.contains($0) })
    }

    func pokeProfile(token: String?, user: User) async {
        guard let token = token else { return }

        do {
            let response = try await MatchService.shared.poke(token: token, userId: user.id)
            pokedIds.insert(user.id)

            if response.status == "matched" {
                matchedUser = user
                matchedMatch = response.match
                showMatchAlert = true

                if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                    let content = UNMutableNotificationContent()
                    content.title = "It's a Match!"
                    content.body = "You and \(user.displayName) both want to play!"
                    content.sound = .default
                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString, content: content, trigger: nil
                    )
                    try? await UNUserNotificationCenter.current().add(request)
                }
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
