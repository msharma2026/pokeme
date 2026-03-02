import SwiftUI

private enum MatchFilter: String, CaseIterable {
    case all = "All"
    case oneOnOne = "1-on-1"
    case group = "Group"
}

struct MatchesListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MatchViewModel()
    @State private var selectedMatch: Match?
    @State private var selectedGroupChat: Meetup?
    @State private var animateEmpty = false
    @State private var selectedFilter: MatchFilter = .all

    private var currentUserId: String { authViewModel.user?.id ?? "" }

    private var isEmpty: Bool { viewModel.matches.isEmpty && viewModel.groupChats.isEmpty }

    private var filteredMatches: [Match] {
        selectedFilter == .group ? [] : viewModel.matches
    }

    private var filteredGroupChats: [Meetup] {
        selectedFilter == .oneOnOne ? [] : viewModel.groupChats
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.orange)
                        Text("Loading matches...").foregroundColor(.secondary)
                    }
                } else if isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Segmented control
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(MatchFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        List {
                            // Meetup group chats
                            if !filteredGroupChats.isEmpty {
                                Section("Group Chats") {
                                    ForEach(filteredGroupChats) { meetup in
                                        Button(action: { selectedGroupChat = meetup }) {
                                            MeetupGroupChatRow(meetup: meetup)
                                        }
                                    }
                                }
                            }

                            // 1-on-1 matches
                            if !filteredMatches.isEmpty {
                                Section("1-on-1") {
                                    ForEach(filteredMatches) { match in
                                        Button(action: { selectedMatch = match }) {
                                            MatchRow(match: match, currentUserId: currentUserId)
                                        }
                                    }
                                }
                            }

                            // Empty filter state
                            if filteredMatches.isEmpty && filteredGroupChats.isEmpty && !isEmpty {
                                Section {
                                    Text("No \(selectedFilter.rawValue.lowercased()) chats yet")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 20)
                                        .listRowBackground(Color.clear)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Matches")
            .task {
                await viewModel.fetchMatches(token: authViewModel.getToken())
            }
            .onAppear {
                viewModel.startPolling(token: authViewModel.getToken())
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .sheet(item: $selectedMatch) { match in
                ChatView(matchId: match.id, partnerName: match.partnerName)
                    .environmentObject(authViewModel)
            }
            .sheet(item: $selectedGroupChat) { meetup in
                MeetupChatView(meetupId: meetup.id, meetupTitle: meetup.title)
                    .environmentObject(authViewModel)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.orange.opacity(0.15), .pink.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateEmpty ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateEmpty)

                Image(systemName: "message.badge.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        .linearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            Text("No matches yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Poke people in Discover to get matched!")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToDiscover"), object: nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sportscourt.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Go to Discover")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(25)
                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding()
        .onAppear { animateEmpty = true }
    }
}

struct MeetupGroupChatRow: View {
    let meetup: Meetup

    var body: some View {
        HStack(spacing: 12) {
            // Group avatar with sport emoji overlay
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)

                VStack(spacing: 1) {
                    Text(sportEmoji(meetup.sport))
                        .font(.system(size: 16))
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(meetup.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(meetup.participantCount) players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(meetup.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }

    private func sportEmoji(_ sport: String) -> String {
        switch sport.lowercased() {
        case "basketball": return "🏀"
        case "tennis": return "🎾"
        case "soccer": return "⚽"
        case "volleyball": return "🏐"
        case "badminton": return "🏸"
        case "running": return "🏃"
        case "swimming": return "🏊"
        case "cycling": return "🚴"
        case "table tennis": return "🏓"
        case "football": return "🏈"
        case "baseball": return "⚾"
        case "golf": return "⛳"
        case "hiking": return "🥾"
        case "yoga": return "🧘"
        case "rock climbing": return "🧗"
        default: return "🏅"
        }
    }
}

struct MatchRow: View {
    let match: Match
    let currentUserId: String

    /// True when the partner sent the most recent message (proxy for "unread")
    private var hasUnread: Bool {
        guard let last = match.lastMessage else { return false }
        return last.senderId != currentUserId
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 52, height: 52)

                    if let pictureData = match.partnerProfilePicture,
                       let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 46, height: 46)
                            .overlay(
                                Text(match.partnerName.prefix(1).uppercased())
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        .linearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            )
                    }
                }

                // Unread dot
                if hasUnread {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(match.partnerName)
                        .font(.headline)
                        .fontWeight(hasUnread ? .bold : .semibold)

                    if let sports = match.partnerSports, let first = sports.first {
                        Text(sportEmoji(first.sport))
                            .font(.caption)
                    }
                }

                if let lastMessage = match.lastMessage {
                    Text(lastMessage.text)
                        .font(.subheadline)
                        .foregroundColor(hasUnread ? .primary : .secondary)
                        .fontWeight(hasUnread ? .medium : .regular)
                        .lineLimit(1)
                } else {
                    Text("Start chatting!")
                        .font(.subheadline)
                        .foregroundStyle(
                            .linearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .italic()
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let lastMessage = match.lastMessage {
                    Text(relativeTime(lastMessage.createdAt))
                        .font(.caption2)
                        .foregroundColor(hasUnread ? .orange : .secondary)
                        .fontWeight(hasUnread ? .semibold : .regular)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func sportEmoji(_ sport: String) -> String {
        switch sport.lowercased() {
        case "basketball": return "🏀"
        case "tennis": return "🎾"
        case "soccer": return "⚽"
        case "volleyball": return "🏐"
        case "badminton": return "🏸"
        case "running": return "🏃"
        case "swimming": return "🏊"
        case "cycling": return "🚴"
        case "table tennis": return "🏓"
        case "football": return "🏈"
        case "baseball": return "⚾"
        case "golf": return "⛳"
        case "hiking": return "🥾"
        case "yoga": return "🧘"
        case "rock climbing": return "🧗"
        default: return "🏅"
        }
    }

    private func relativeTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date: Date? = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        guard let date = date else { return "" }

        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let days = seconds / 86400
        if days < 7 { return "\(days)d" }
        let df = DateFormatter()
        df.dateStyle = .short
        return df.string(from: date)
    }
}
