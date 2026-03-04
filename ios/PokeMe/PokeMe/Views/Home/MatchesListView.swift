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
    @State private var selectedProfileMatch: Match?
    @State private var selectedGroupMembers: Meetup?
    @State private var animateEmpty = false
    @AppStorage("matchesSelectedFilter") private var selectedFilterRaw: String = MatchFilter.all.rawValue

    private var selectedFilter: MatchFilter {
        get { MatchFilter(rawValue: selectedFilterRaw) ?? .all }
        set { selectedFilterRaw = newValue.rawValue }
    }

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
                        Picker("Filter", selection: $selectedFilterRaw) {
                            ForEach(MatchFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter.rawValue)
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
                                            MeetupGroupChatRow(
                                                meetup: meetup,
                                                onAvatarTap: { selectedGroupMembers = meetup }
                                            )
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.leaveMeetup(token: authViewModel.getToken(), meetupId: meetup.id) }
                                            } label: {
                                                Label(meetup.hostId == currentUserId ? "Delete" : "Leave", systemImage: "rectangle.portrait.and.arrow.right")
                                            }
                                            Button {
                                                selectedGroupMembers = meetup
                                            } label: {
                                                Label("Members", systemImage: "person.3")
                                            }
                                            .tint(.blue)
                                        }
                                        .contextMenu {
                                            Button {
                                                selectedGroupMembers = meetup
                                            } label: {
                                                Label("View Members", systemImage: "person.3")
                                            }
                                            Button(role: .destructive) {
                                                Task { await viewModel.leaveMeetup(token: authViewModel.getToken(), meetupId: meetup.id) }
                                            } label: {
                                                Label(meetup.hostId == currentUserId ? "Delete Group" : "Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                                            }
                                        }
                                    }
                                }
                            }

                            // 1-on-1 matches
                            if !filteredMatches.isEmpty {
                                Section("1-on-1") {
                                    ForEach(filteredMatches) { match in
                                        Button(action: { selectedMatch = match }) {
                                            MatchRow(
                                                match: match,
                                                currentUserId: currentUserId,
                                                onAvatarTap: { selectedProfileMatch = match }
                                            )
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.deleteMatch(token: authViewModel.getToken(), matchId: match.id) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                selectedProfileMatch = match
                                            } label: {
                                                Label("Profile", systemImage: "person.circle")
                                            }
                                            .tint(.blue)
                                        }
                                        .contextMenu {
                                            Button {
                                                selectedProfileMatch = match
                                            } label: {
                                                Label("View Profile", systemImage: "person.circle")
                                            }
                                            Button(role: .destructive) {
                                                Task { await viewModel.deleteMatch(token: authViewModel.getToken(), matchId: match.id) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
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
                Task {
                    await viewModel.fetchMatches(token: authViewModel.getToken())
                }
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
            .sheet(item: $selectedProfileMatch) { match in
                PartnerProfileSheet(match: match)
            }
            .sheet(item: $selectedGroupMembers) { meetup in
                GroupMembersSheet(meetup: meetup)
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
    var onAvatarTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Group avatar (tappable to view members)
            Button(action: { onAvatarTap?() }) {
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
            }
            .buttonStyle(.plain)

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
    var onAvatarTap: (() -> Void)? = nil

    /// True when the partner sent the most recent message (proxy for "unread")
    private var hasUnread: Bool {
        guard let last = match.lastMessage else { return false }
        return last.senderId != currentUserId
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar (tappable to view profile)
            Button(action: { onAvatarTap?() }) {
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
            } // end avatar Button
            .buttonStyle(.plain)

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

// MARK: - Group Members Sheet

struct GroupMembersSheet: View {
    let meetup: Meetup
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var participants: [User] = []
    @State private var isLoading = true
    @State private var selectedUser: User?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.purple)
                        Text("Loading members…").foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(participants) { user in
                        Button(action: { selectedUser = user }) {
                            MemberRow(user: user, isCurrentUser: user.id == authViewModel.user?.id)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(meetup.title) Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
            }
            .task {
                guard let token = authViewModel.getToken() else { return }
                if let response = try? await MeetupService.shared.getParticipants(token: token, meetupId: meetup.id) {
                    participants = response.participants
                }
                isLoading = false
            }
            .sheet(item: $selectedUser) { user in
                UserProfileSheet(user: user)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct MemberRow: View {
    let user: User
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                if let data = user.profilePicture,
                   let imageData = Data(base64Encoded: data.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                } else {
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.headline)
                    if isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(6)
                    }
                }
                if let year = user.collegeYear {
                    Text(year)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !isCurrentUser {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - User Profile Sheet

struct UserProfileSheet: View {
    let user: User
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    ZStack {
                        LinearGradient(colors: [.purple, .indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 200)

                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 96, height: 96)
                                if let data = user.profilePicture,
                                   let imageData = Data(base64Encoded: data.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else {
                                    Text(user.displayName.prefix(1).uppercased())
                                        .font(.system(size: 38, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                            Text(user.displayName)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if let year = user.collegeYear {
                                Text(year)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.top, 16)
                    }

                    // Sports
                    if let sports = user.sports, !sports.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Sports", systemImage: "figure.run")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sports) { sport in
                                        HStack(spacing: 4) {
                                            Text(sport.sport).fontWeight(.medium)
                                            Text(sport.skillLevel)
                                                .font(.caption)
                                                .foregroundColor(.purple.opacity(0.7))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.12))
                                        .foregroundColor(.purple)
                                        .cornerRadius(14)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }

                    // Bio
                    if let bio = user.bio, !bio.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Bio", systemImage: "text.quote")
                                .font(.headline)
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Partner Profile Sheet

struct PartnerProfileSheet: View {
    let match: Match
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    ZStack {
                        LinearGradient(
                            colors: [.orange, .pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 200)

                        VStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 96, height: 96)

                                if let pictureData = match.partnerProfilePicture,
                                   let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else {
                                    Text(match.partnerName.prefix(1).uppercased())
                                        .font(.system(size: 38, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }

                            Text(match.partnerName)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            if let year = match.partnerCollegeYear {
                                Text(year)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.top, 16)
                    }

                    // Sports section
                    if let sports = match.partnerSports, !sports.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Sports", systemImage: "figure.run")
                                .font(.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sports) { sport in
                                        HStack(spacing: 4) {
                                            Text(sport.sport)
                                                .fontWeight(.medium)
                                            Text(sport.skillLevel)
                                                .font(.caption)
                                                .foregroundColor(.orange.opacity(0.7))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.12))
                                        .foregroundColor(.orange)
                                        .cornerRadius(14)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

