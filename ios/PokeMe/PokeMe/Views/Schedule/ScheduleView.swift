import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var matchViewModel: MatchViewModel
    @EnvironmentObject var meetupViewModel: MeetupViewModel
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var selectedSegment = 0
    @State private var sortOption: SortOption = .date
    @State private var expandedId: String? = nil
    @State private var showProposal = false
    @State private var proposalSession: Session? = nil
    @State private var showCreateAfterCancel = false
    @State private var recreatePrefill: Meetup? = nil
    @State private var confirmAction: ConfirmAction? = nil

    enum SortOption: String, CaseIterable {
        case date = "Date"
        case sport = "Sport"
        case type = "Type"
    }

    enum ConfirmAction: Identifiable {
        case cancelMeetup(Meetup)
        case leaveMeetup(Meetup)

        var id: String {
            switch self {
            case .cancelMeetup(let m): return "cancel-\(m.id)"
            case .leaveMeetup(let m): return "leave-\(m.id)"
            }
        }
    }

    private var token: String { authViewModel.getToken() ?? "" }

    private var displayedItems: [ScheduleViewModel.ScheduleItem] {
        let base = selectedSegment == 0 ? viewModel.upcomingItems : viewModel.pastItems
        switch sortOption {
        case .date:
            return base
        case .sport:
            return base.sorted { sportName($0) < sportName($1) }
        case .type:
            return base.sorted { typeSortKey($0) < typeSortKey($1) }
        }
    }

    private func sportName(_ item: ScheduleViewModel.ScheduleItem) -> String {
        switch item {
        case .session(let s): return s.sport
        case .meetup(let m): return m.sport
        }
    }

    private func typeSortKey(_ item: ScheduleViewModel.ScheduleItem) -> Int {
        switch item {
        case .session: return 0
        case .meetup: return 1
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedSegment) {
                    Text("Upcoming").tag(0)
                    Text("Past").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                sortPillsRow

                List {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.top, 60)
                    } else if displayedItems.isEmpty {
                        emptyStateRow
                    } else {
                        ForEach(displayedItems) { item in
                            scheduleCardRow(item)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.fetch(
                        token: token,
                        currentUserId: authViewModel.user?.id ?? ""
                    )
                }
            }
            .navigationTitle("Schedule")
            .task {
                await viewModel.fetch(
                    token: token,
                    currentUserId: authViewModel.user?.id ?? ""
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshSchedule"))) { _ in
                Task {
                    await viewModel.fetch(
                        token: token,
                        currentUserId: authViewModel.user?.id ?? ""
                    )
                }
            }
            .sheet(isPresented: $showProposal) {
                if let session = proposalSession {
                    ProposalSheet(
                        matchId: session.matchId,
                        token: token,
                        prefillSession: session,
                        onProposed: {
                            Task {
                                await viewModel.fetch(
                                    token: token,
                                    currentUserId: authViewModel.user?.id ?? ""
                                )
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showCreateAfterCancel) {
                CreateMeetupView(viewModel: meetupViewModel, prefill: recreatePrefill)
                    .environmentObject(authViewModel)
            }
            .alert(item: $confirmAction) { action in
                switch action {
                case .cancelMeetup(let m):
                    return Alert(
                        title: Text("Cancel Meetup?"),
                        message: Text("This cancels the meetup for all participants. You can recreate it next."),
                        primaryButton: .destructive(Text("Cancel Meetup")) {
                            Task { await doCancelAndRecreate(m) }
                        },
                        secondaryButton: .cancel()
                    )
                case .leaveMeetup(let m):
                    return Alert(
                        title: Text("Leave Meetup?"),
                        primaryButton: .destructive(Text("Leave")) {
                            Task { await doLeaveMeetup(m) }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
    }

    // MARK: - Sort Pills

    private var sortPillsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        Text(option.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(sortOption == option ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    sortOption == option
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [.orange, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing))
                                        : AnyShapeStyle(Color(uiColor: .systemGray6))
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Empty State

    private var emptyStateRow: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text(selectedSegment == 0 ? "No upcoming sessions" : "No past sessions")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(selectedSegment == 0
                 ? "Accept a session proposal or join a meetup to see it here."
                 : "Your completed sessions will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Card Row

    @ViewBuilder
    private func scheduleCardRow(_ item: ScheduleViewModel.ScheduleItem) -> some View {
        let isPast = selectedSegment == 1
        let isExpanded = expandedId == item.id

        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible, tappable to toggle
            HStack(spacing: 14) {
                Text(itemEmoji(item))
                    .font(.system(size: 32))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(itemTitle(item))
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        sourceBadge(item)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(itemSubtitle(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(itemDateDisplay(item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let loc = itemLocation(item), !loc.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(loc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    expandedId = isExpanded ? nil : item.id
                }
            }

            // Expanded section
            if isExpanded {
                Divider()
                    .padding(.top, 4)
                expandedSection(item, isPast: isPast)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .padding(.leading, 58)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func expandedSection(_ item: ScheduleViewModel.ScheduleItem, isPast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            expandedDetails(item)
            expandedParticipants(item)
            if !isPast {
                expandedActions(item)
            }
        }
    }

    @ViewBuilder
    private func expandedParticipants(_ item: ScheduleViewModel.ScheduleItem) -> some View {
        switch item {
        case .session(let s):
            if let match = matchViewModel.matches.first(where: { $0.id == s.matchId }) {
                SessionPartnerRow(match: match)
                    .padding(.trailing, 16)
            }
        case .meetup(let m):
            ScheduleMeetupParticipants(meetupId: m.id, token: token)
                .padding(.trailing, 16)
        }
    }

    @ViewBuilder
    private func expandedDetails(_ item: ScheduleViewModel.ScheduleItem) -> some View {
        switch item {
        case .session(let s):
            VStack(alignment: .leading, spacing: 6) {
                detailRow(icon: "figure.run", label: "Sport", value: s.sport)
                detailRow(icon: "calendar", label: "Date",
                          value: formatShortDate(s.date, fallback: s.day))
                detailRow(icon: "clock", label: "Time",
                          value: "\(AvailabilityHelper.formatHour(s.startHour))–\(AvailabilityHelper.formatHour(s.endHour))")
                if let loc = s.location, !loc.isEmpty {
                    detailRow(icon: "mappin", label: "Location", value: loc)
                }
            }
        case .meetup(let m):
            VStack(alignment: .leading, spacing: 6) {
                detailRow(icon: "figure.run", label: "Sport", value: m.sport)
                detailRow(icon: "calendar", label: "Date", value: formatShortDate(m.date, fallback: m.date))
                detailRow(icon: "clock", label: "Time", value: formatMeetupTime(m.time))
                if let loc = m.location, !loc.isEmpty {
                    detailRow(icon: "mappin", label: "Location", value: loc)
                }
                detailRow(icon: "person", label: "Host", value: m.hostName)
            }
        }
    }

    @ViewBuilder
    private func expandedActions(_ item: ScheduleViewModel.ScheduleItem) -> some View {
        switch item {
        case .session(let s):
            Button {
                proposalSession = s
                showProposal = true
            } label: {
                Text("Propose Change")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .padding(.top, 4)

        case .meetup(let m):
            if m.hostId == authViewModel.user?.id {
                Button { confirmAction = .cancelMeetup(m) } label: {
                    Text("Cancel & Recreate")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 4)
            } else {
                Button { confirmAction = .leaveMeetup(m) } label: {
                    Text("Leave Meetup")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }

    // MARK: - Badge

    @ViewBuilder
    private func sourceBadge(_ item: ScheduleViewModel.ScheduleItem) -> some View {
        switch item {
        case .session:
            Text("Session")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
        case .meetup:
            Text("Meetup")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
        }
    }

    // MARK: - Item Helpers

    private func itemEmoji(_ item: ScheduleViewModel.ScheduleItem) -> String {
        switch item {
        case .session(let s): return AvailabilityHelper.sportEmoji(for: s.sport) ?? "📅"
        case .meetup(let m):  return AvailabilityHelper.sportEmoji(for: m.sport) ?? "📅"
        }
    }

    private func itemTitle(_ item: ScheduleViewModel.ScheduleItem) -> String {
        switch item {
        case .session(let s): return s.sport
        case .meetup(let m):  return m.title
        }
    }

    private func itemSubtitle(_ item: ScheduleViewModel.ScheduleItem) -> String {
        switch item {
        case .session(let s):
            let name = matchViewModel.matches.first { $0.id == s.matchId }?.partnerName ?? "Session"
            return "with \(name)"
        case .meetup(let m):
            let count = m.participantCount
            return "\(count) participant\(count == 1 ? "" : "s")"
        }
    }

    private func itemDateDisplay(_ item: ScheduleViewModel.ScheduleItem) -> String {
        switch item {
        case .session(let s):
            let dateStr = AvailabilityHelper.formatSessionDate(s.date, fallback: s.day)
            let timeStr = "\(AvailabilityHelper.formatHour(s.startHour))–\(AvailabilityHelper.formatHour(s.endHour))"
            return "\(dateStr) · \(timeStr)"
        case .meetup(let m):
            return "\(formatMeetupDateShort(m.date)) · \(formatMeetupTime(m.time))"
        }
    }

    private func itemLocation(_ item: ScheduleViewModel.ScheduleItem) -> String? {
        switch item {
        case .session(let s): return s.location
        case .meetup(let m):  return m.location
        }
    }

    /// Converts "yyyy-MM-dd" → "EEE, M/d" (e.g. "Wed, 3/12").
    private func formatMeetupDateShort(_ isoDate: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: isoDate) else { return isoDate }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "EEE, M/d"
        return output.string(from: date)
    }

    /// Converts "HH:mm" → "h:mm a" (e.g. "14:30" → "2:30 PM").
    private func formatMeetupTime(_ hhmm: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "HH:mm"
        guard let date = input.date(from: hhmm) else { return hhmm }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "h:mm a"
        return output.string(from: date)
    }

    /// Converts "yyyy-MM-dd" → "M/d/yy" (e.g. "3/7/26"); falls back to `fallback` if unparseable.
    private func formatShortDate(_ isoDate: String?, fallback: String) -> String {
        guard let isoDate, !isoDate.isEmpty else { return fallback }
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: isoDate) else { return fallback }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "M/d/yy"
        return output.string(from: date)
    }

    // MARK: - Action Helpers

    private func doCancelAndRecreate(_ meetup: Meetup) async {
        try? await MeetupService.shared.cancelMeetup(token: token, meetupId: meetup.id)
        recreatePrefill = meetup
        showCreateAfterCancel = true
        await viewModel.fetch(token: token, currentUserId: authViewModel.user?.id ?? "")
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMeetups"), object: nil)
    }

    private func doLeaveMeetup(_ meetup: Meetup) async {
        _ = try? await MeetupService.shared.leaveMeetup(token: token, meetupId: meetup.id)
        await viewModel.fetch(token: token, currentUserId: authViewModel.user?.id ?? "")
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMeetups"), object: nil)
    }
}

// MARK: - SessionPartnerRow

struct SessionPartnerRow: View {
    let match: Match
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var showProfile = false

    private var partnerUser: User {
        User(
            id: match.partnerId,
            email: nil,
            phone: nil,
            displayName: match.partnerName,
            major: match.partnerMajor,
            bio: match.partnerBio,
            profilePicture: match.partnerProfilePicture,
            socials: match.partnerSocials,
            sports: match.partnerSports,
            collegeYear: match.partnerCollegeYear,
            availability: match.partnerAvailability,
            recommendationScore: nil,
            recommendationReasons: nil,
            recommendationBreakdown: nil,
            createdAt: match.createdAt
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Partner")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button { showProfile = true } label: {
                HStack(spacing: 10) {
                    partnerAvatar
                    Text(match.partnerName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showProfile) {
            NavigationView {
                ParticipantProfileSheet(user: partnerUser)
                    .environmentObject(authViewModel)
                    .navigationTitle(match.partnerName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showProfile = false }
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var partnerAvatar: some View {
        if let pic = match.partnerProfilePicture, !pic.isEmpty, let url = URL(string: pic) {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    initialCircle(match.partnerName)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            initialCircle(match.partnerName)
        }
    }

    private func initialCircle(_ name: String) -> some View {
        Circle()
            .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 36, height: 36)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - ScheduleMeetupParticipants

struct ScheduleMeetupParticipants: View {
    let meetupId: String
    let token: String
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var participants: [User] = []
    @State private var isLoading = false
    @State private var showAllSheet = false
    @State private var selectedUser: User? = nil

    private let maxVisible = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Participants")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if participants.isEmpty {
                Text("No participants yet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(participants.prefix(maxVisible)) { user in
                            Button { selectedUser = user } label: {
                                participantAvatar(user)
                            }
                            .buttonStyle(.plain)
                        }
                        if participants.count > maxVisible {
                            Button { showAllSheet = true } label: {
                                Text("+\(participants.count - maxVisible) more")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .task { await fetchParticipants() }
        .sheet(isPresented: $showAllSheet) {
            AllParticipantsSheet(participants: participants)
                .environmentObject(authViewModel)
        }
        .sheet(item: $selectedUser) { user in
            NavigationView {
                ParticipantProfileSheet(user: user)
                    .environmentObject(authViewModel)
                    .navigationTitle(user.displayName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { selectedUser = nil }
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func participantAvatar(_ user: User) -> some View {
        VStack(spacing: 3) {
            if let pic = user.profilePicture, !pic.isEmpty, let url = URL(string: pic) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        initialCircle(user.displayName, size: 36)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                initialCircle(user.displayName, size: 36)
            }
            Text(user.displayName.components(separatedBy: " ").first ?? user.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 40)
        }
    }

    private func initialCircle(_ name: String, size: CGFloat) -> some View {
        Circle()
            .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private func fetchParticipants() async {
        // Serve from cache if still fresh (5-min TTL)
        if let cached = MeetupParticipantsCache.shared.participants(for: meetupId) {
            participants = cached
            return
        }
        isLoading = true
        do {
            let response = try await MeetupService.shared.getParticipants(token: token, meetupId: meetupId)
            participants = response.participants
            MeetupParticipantsCache.shared.store(response.participants, for: meetupId)
        } catch {
            // silently fail
        }
        isLoading = false
    }
}

// MARK: - AllParticipantsSheet

struct AllParticipantsSheet: View {
    let participants: [User]
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedUser: User? = nil

    var body: some View {
        NavigationView {
            List(participants) { user in
                Button {
                    selectedUser = user
                } label: {
                    HStack(spacing: 12) {
                        avatarView(user)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            if let year = user.collegeYear {
                                Text(year.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedUser) { user in
                NavigationView {
                    ParticipantProfileSheet(user: user)
                        .environmentObject(authViewModel)
                        .navigationTitle(user.displayName)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { selectedUser = nil }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func avatarView(_ user: User) -> some View {
        if let pic = user.profilePicture, !pic.isEmpty, let url = URL(string: pic) {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    initialCircle(user.displayName)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            initialCircle(user.displayName)
        }
    }

    private func initialCircle(_ name: String) -> some View {
        Circle()
            .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}
