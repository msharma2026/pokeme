import SwiftUI

private enum MatchFilter: String, CaseIterable {
    case all = "All"
    case oneOnOne = "1-on-1"
    case group = "Group"
    case deleted = "Deleted"
}

struct MatchesListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MatchViewModel()
    @State private var selectedMatch: Match?
    @State private var selectedGroupChat: Meetup?
    @State private var selectedProfileMatch: Match?
    @State private var selectedGroupMembers: Meetup?
    @State private var matchPendingDelete: Match?
    @State private var meetupPendingLeave: Meetup?
    @State private var matchPendingBlock: Match?
    @State private var animateEmpty = false
    @AppStorage("matchesSelectedFilter") private var selectedFilterRaw: String = MatchFilter.all.rawValue

    private var selectedFilter: MatchFilter {
        get { MatchFilter(rawValue: selectedFilterRaw) ?? .all }
        set { selectedFilterRaw = newValue.rawValue }
    }

    private var currentUserId: String { authViewModel.user?.id ?? "" }

    private var isEmpty: Bool { viewModel.matches.isEmpty && viewModel.groupChats.isEmpty }

    private var filteredMatches: [Match] {
        (selectedFilter == .group || selectedFilter == .deleted) ? [] : viewModel.matches
    }

    private var filteredGroupChats: [Meetup] {
        (selectedFilter == .oneOnOne || selectedFilter == .deleted) ? [] : viewModel.groupChats
    }

    private var isTrashEmpty: Bool {
        viewModel.deletedMatches.isEmpty && viewModel.deletedMeetups.isEmpty && viewModel.blockedMatches.isEmpty
    }

    private var filterPickerRow: some View {
        Picker("Filter", selection: $selectedFilterRaw) {
            ForEach(MatchFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 4)
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.orange)
                        Text("Loading matches...").foregroundColor(.secondary)
                    }
                } else if isEmpty && selectedFilter != .deleted {
                    emptyState
                } else {
                    Group {
                        if selectedFilter == .deleted {
                            deletedTab
                        } else {
                            List {
                                Section {
                                    filterPickerRow
                                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
                                }

                                // Meetup group chats
                                if !filteredGroupChats.isEmpty {
                                    Section("Group Chats") {
                                        ForEach(filteredGroupChats) { meetup in
                                            Button(action: {
                                                viewModel.markGroupChatRead(meetupId: meetup.id)
                                                selectedGroupChat = meetup
                                            }) {
                                                MeetupGroupChatRow(
                                                    meetup: meetup,
                                                    unreadCount: viewModel.groupChatUnreadCounts[meetup.id] ?? 0,
                                                    onAvatarTap: { selectedGroupMembers = meetup }
                                                )
                                            }
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    meetupPendingLeave = meetup
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
                                                    meetupPendingLeave = meetup
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
                                                    matchPendingDelete = match
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                Button {
                                                    matchPendingBlock = match
                                                } label: {
                                                    Label("Block", systemImage: "hand.raised")
                                                }
                                                .tint(.indigo)
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
                                                Button {
                                                    matchPendingBlock = match
                                                } label: {
                                                    Label("Block", systemImage: "hand.raised")
                                                }
                                                Button(role: .destructive) {
                                                    matchPendingDelete = match
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
            }
            .navigationTitle("Matches")
            .refreshable {
                await refreshMatches()
            }
            .task {
                await refreshMatches()
            }
            .onAppear {
                Task {
                    await refreshMatches()
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
            .alert("Delete Match?", isPresented: Binding(
                get: { matchPendingDelete != nil },
                set: { if !$0 { matchPendingDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let match = matchPendingDelete {
                        Task { await viewModel.deleteMatch(token: authViewModel.getToken(), matchId: match.id) }
                    }
                    matchPendingDelete = nil
                }
                Button("Cancel", role: .cancel) { matchPendingDelete = nil }
            } message: {
                if let match = matchPendingDelete {
                    Text("Remove your match with \(match.partnerName)? This can't be undone.")
                }
            }
            .alert(
                meetupPendingLeave.map { $0.hostId == currentUserId ? "Delete Group?" : "Leave Group?" } ?? "Leave Group?",
                isPresented: Binding(
                    get: { meetupPendingLeave != nil },
                    set: { if !$0 { meetupPendingLeave = nil } }
                )
            ) {
                Button(meetupPendingLeave.map { $0.hostId == currentUserId ? "Delete" : "Leave" } ?? "Leave", role: .destructive) {
                    if let meetup = meetupPendingLeave {
                        Task { await viewModel.leaveMeetup(token: authViewModel.getToken(), meetupId: meetup.id) }
                    }
                    meetupPendingLeave = nil
                }
                Button("Cancel", role: .cancel) { meetupPendingLeave = nil }
            } message: {
                if let meetup = meetupPendingLeave {
                    let action = meetup.hostId == currentUserId ? "Deleting" : "Leaving"
                    Text("\(action) \"\(meetup.title)\" is permanent and can't be undone.")
                }
            }
            .alert(
                "Block \(matchPendingBlock?.partnerName ?? "User")?",
                isPresented: Binding(
                    get: { matchPendingBlock != nil },
                    set: { if !$0 { matchPendingBlock = nil } }
                )
            ) {
                Button("Block", role: .destructive) {
                    if let match = matchPendingBlock {
                        Task { await viewModel.blockMatch(token: authViewModel.getToken(), matchId: match.id) }
                    }
                    matchPendingBlock = nil
                }
                Button("Cancel", role: .cancel) { matchPendingBlock = nil }
            } message: {
                if let match = matchPendingBlock {
                    Text("Block \(match.partnerName)? They will be moved to your blocked list and won't be able to contact you.")
                }
            }
        }
    }

    @State private var showClearTrashConfirm = false

    // MARK: - Deleted Tab

    private var deletedTab: some View {
        Group {
            if isTrashEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Trash is empty")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    Section {
                        filterPickerRow
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
                    }

                    if !viewModel.deletedMatches.isEmpty {
                        Section("Deleted 1-on-1") {
                            ForEach(viewModel.deletedMatches) { match in
                                DeletedMatchRow(match: match)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            viewModel.permanentlyDeleteMatch(id: match.id)
                                        } label: {
                                            Label("Remove", systemImage: "xmark.bin")
                                        }
                                        Button {
                                            viewModel.restoreMatch(id: match.id)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.green)
                                    }
                                    .contextMenu {
                                        Button {
                                            viewModel.restoreMatch(id: match.id)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }
                                        Button(role: .destructive) {
                                            viewModel.permanentlyDeleteMatch(id: match.id)
                                        } label: {
                                            Label("Remove Permanently", systemImage: "xmark.bin")
                                        }
                                    }
                            }
                        }
                    }

                    if !viewModel.deletedMeetups.isEmpty {
                        Section("Left Group Chats") {
                            ForEach(viewModel.deletedMeetups) { meetup in
                                DeletedMeetupRow(meetup: meetup)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            viewModel.permanentlyDeleteMeetup(id: meetup.id)
                                        } label: {
                                            Label("Remove", systemImage: "xmark.bin")
                                        }
                                        Button {
                                            viewModel.restoreMeetup(id: meetup.id)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.green)
                                    }
                                    .contextMenu {
                                        Button {
                                            viewModel.restoreMeetup(id: meetup.id)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }
                                        Button(role: .destructive) {
                                            viewModel.permanentlyDeleteMeetup(id: meetup.id)
                                        } label: {
                                            Label("Remove Permanently", systemImage: "xmark.bin")
                                        }
                                    }
                            }
                        }
                    }

                    if !viewModel.blockedMatches.isEmpty {
                        Section("Blocked") {
                            ForEach(viewModel.blockedMatches) { match in
                                BlockedMatchRow(match: match)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            viewModel.unblockMatch(id: match.id)
                                        } label: {
                                            Label("Unblock", systemImage: "hand.raised.slash")
                                        }
                                        .tint(.green)
                                    }
                                    .contextMenu {
                                        Button {
                                            viewModel.unblockMatch(id: match.id)
                                        } label: {
                                            Label("Unblock", systemImage: "hand.raised.slash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Empty Trash") { showClearTrashConfirm = true }
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
                .alert("Empty Trash?", isPresented: $showClearTrashConfirm) {
                    Button("Empty Trash", role: .destructive) { viewModel.clearTrash() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Permanently remove all deleted chats. This can't be undone.")
                }
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                filterPickerRow
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

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
            .frame(maxWidth: .infinity)
        }
        .onAppear { animateEmpty = true }
    }

    private func refreshMatches() async {
        await viewModel.fetchMatches(token: authViewModel.getToken())
        await viewModel.fetchGroupChats(token: authViewModel.getToken())
    }
}

// MARK: - Deleted Item Rows

struct DeletedMatchRow: View {
    let match: Match

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 46, height: 46)
                if let pictureData = match.partnerProfilePicture,
                   let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .grayscale(1)
                } else {
                    Text(match.partnerName.prefix(1).uppercased())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(match.partnerName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("1-on-1 match")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "trash")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
}

struct DeletedMeetupRow: View {
    let meetup: Meetup

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 46, height: 46)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(meetup.title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("Group · \(meetup.sport)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "trash")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }
}

struct BlockedMatchRow: View {
    let match: Match

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 46, height: 46)
                if let pictureData = match.partnerProfilePicture,
                   let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .grayscale(1)
                } else {
                    Text(match.partnerName.prefix(1).uppercased())
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(match.partnerName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Blocked")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
            }
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.caption)
                .foregroundColor(.red.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}

struct MeetupGroupChatRow: View {
    let meetup: Meetup
    var unreadCount: Int = 0
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
                .overlay(alignment: .topTrailing) {
                    if unreadCount > 0 {
                        Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple))
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(meetup.title)
                    .font(.headline)
                    .fontWeight(unreadCount > 0 ? .bold : .semibold)
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

    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let dayAbbrs = ["M", "T", "W", "T", "F", "S", "S"]
    private let slots = ["Morning", "Afternoon", "Evening"]

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
                        .frame(height: 220)

                        VStack(spacing: 10) {
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
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            HStack(spacing: 8) {
                                if let year = match.partnerCollegeYear {
                                    Text(year)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(10)
                                }
                                if let major = match.partnerMajor, !major.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "book.closed.fill")
                                            .font(.caption2)
                                        Text(major)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.top, 20)
                    }

                    VStack(spacing: 12) {
                        // Sports
                        if let sports = match.partnerSports, !sports.isEmpty {
                            profileSection(title: "Sports", icon: "trophy.fill", gradient: [.orange, .pink]) {
                                VStack(spacing: 8) {
                                    ForEach(sports) { sport in
                                        HStack {
                                            Text(sportEmoji(sport.sport))
                                                .font(.title3)
                                            Text(sport.sport)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(sport.skillLevel)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(skillColor(sport.skillLevel))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                        }

                        // Availability
                        if let availability = match.partnerAvailability, !availability.isEmpty {
                            profileSection(title: "Availability", icon: "calendar", gradient: [.green, .teal]) {
                                availabilityGrid(availability: availability)
                            }
                        }

                        // Bio
                        if let bio = match.partnerBio, !bio.isEmpty {
                            profileSection(title: "About", icon: "quote.bubble.fill", gradient: [.purple, .indigo]) {
                                Text(bio)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Socials
                        if let socials = match.partnerSocials,
                           [socials.instagram, socials.twitter, socials.snapchat, socials.linkedin].contains(where: { $0 != nil && !($0?.isEmpty ?? true) }) {
                            profileSection(title: "Socials", icon: "at", gradient: [.blue, .cyan]) {
                                HStack(spacing: 10) {
                                    if let ig = socials.instagram, !ig.isEmpty {
                                        socialBadge(icon: "camera.fill", label: ig, colors: [.pink, .purple, .orange])
                                    }
                                    if let tw = socials.twitter, !tw.isEmpty {
                                        socialBadge(icon: "at", label: tw, colors: [.blue, .cyan])
                                    }
                                    if let sc = socials.snapchat, !sc.isEmpty {
                                        socialBadge(icon: "message.fill", label: sc, colors: [.yellow, .green])
                                    }
                                    if let li = socials.linkedin, !li.isEmpty {
                                        socialBadge(icon: "briefcase.fill", label: li, colors: [.blue, .indigo])
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
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

    private func profileSection<Content: View>(
        title: String, icon: String, gradient: [Color],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(.linearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                Spacer()
            }
            .padding()

            Divider().padding(.horizontal)

            content()
                .padding()
        }
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(16)
    }

    private func availabilityGrid(availability: [String: [String]]) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                Text("").frame(width: 46)
                ForEach(Array(dayAbbrs.enumerated()), id: \.offset) { _, abbr in
                    Text(abbr)
                        .font(.system(size: 9, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            ForEach(slots, id: \.self) { slot in
                HStack(spacing: 0) {
                    Text(slot)
                        .font(.system(size: 8))
                        .frame(width: 46, alignment: .leading)
                        .foregroundColor(.secondary)
                    ForEach(days, id: \.self) { day in
                        let isOn = availability[day]?.contains(slot) ?? false
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                isOn
                                    ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color(uiColor: .systemGray5), Color(uiColor: .systemGray5)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(height: 18)
                            .padding(1.5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func socialBadge(icon: String, label: String, colors: [Color]) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.linearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("@\(label)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(colors.first?.opacity(0.1) ?? Color.clear)
        .cornerRadius(20)
    }

    private func skillColor(_ level: String) -> LinearGradient {
        switch level {
        case "Advanced":     return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        case "Intermediate": return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        default:             return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        }
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
