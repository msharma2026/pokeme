import Foundation

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var upcomingItems: [ScheduleItem] = []
    @Published var pastItems: [ScheduleItem] = []
    @Published var isLoading = false

    private let sessionsKey = "cachedScheduleSessions"
    private let meetupsKey  = "cachedScheduleMeetups"

    init() {
        loadFromCache()
    }

    private func loadFromCache() {
        guard
            let sd = UserDefaults.standard.data(forKey: sessionsKey),
            let md = UserDefaults.standard.data(forKey: meetupsKey),
            let sessions = try? JSONDecoder().decode([Session].self, from: sd),
            let meetups  = try? JSONDecoder().decode([Meetup].self,   from: md)
        else { return }
        buildItems(sessions: sessions, meetups: meetups)
    }

    private func saveToCache(sessions: [Session], meetups: [Meetup]) {
        if let sd = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(sd, forKey: sessionsKey) }
        if let md = try? JSONEncoder().encode(meetups)  { UserDefaults.standard.set(md, forKey: meetupsKey)  }
    }

    private func buildItems(sessions: [Session], meetups: [Meetup]) {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        let isoToday = fmt.string(from: Date())

        let allItems: [ScheduleItem] = sessions.map { .session($0) } + meetups.map { .meetup($0) }
        var upcoming: [ScheduleItem] = []
        var past: [ScheduleItem] = []
        for item in allItems {
            let dk = item.dateKey
            if dk.isEmpty || dk >= isoToday { upcoming.append(item) } else { past.append(item) }
        }
        upcomingItems = upcoming.sorted {
            let a = $0.dateKey, b = $1.dateKey
            if a.isEmpty && b.isEmpty { return false }
            if a.isEmpty { return false }
            if b.isEmpty { return true }
            return a < b
        }
        pastItems = past.sorted {
            let a = $0.dateKey, b = $1.dateKey
            if a.isEmpty && b.isEmpty { return false }
            if a.isEmpty { return false }
            if b.isEmpty { return true }
            return a > b
        }
    }

    enum ScheduleItem: Identifiable {
        case session(Session)
        case meetup(Meetup)

        var id: String {
            switch self {
            case .session(let s): return "s-\(s.id)"
            case .meetup(let m): return "m-\(m.id)"
            }
        }

        // Normalized "yyyy-MM-dd" key; "" if unparseable → treat as upcoming
        var dateKey: String {
            let raw: String
            switch self {
            case .session(let s): raw = s.date ?? ""
            case .meetup(let m): raw = m.date
            }
            guard !raw.isEmpty else { return "" }
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.date(from: raw) != nil ? raw : ""
        }
    }

    func fetch(token: String, currentUserId: String) async {
        isLoading = upcomingItems.isEmpty && pastItems.isEmpty
        async let sessionsResult = MessageService.shared.getUpcomingSessions(token: token)
        async let meetupsResult  = MeetupService.shared.getMyMeetups(token: token)
        let sessions = (try? await sessionsResult)?.sessions ?? []
        let meetups  = (try? await meetupsResult)?.meetups  ?? []
        buildItems(sessions: sessions, meetups: meetups)
        saveToCache(sessions: sessions, meetups: meetups)
        isLoading = false
    }
}
