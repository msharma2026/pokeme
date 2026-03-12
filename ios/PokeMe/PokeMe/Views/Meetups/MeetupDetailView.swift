import SwiftUI

struct MeetupDetailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: MeetupViewModel
    let meetup: Meetup
    @Environment(\.dismiss) var dismiss

    @State private var participants: [User] = []
    @State private var isLoadingParticipants = false
    @State private var selectedParticipant: User?
    @State private var showGroupChat = false
    @State private var showCancelConfirm = false
    private var currentUserId: String { authViewModel.user?.id ?? "" }
    private var isHost: Bool { meetup.hostId == currentUserId }
    private var isJoined: Bool { meetup.participants?.contains(currentUserId) ?? false }

    private func formatMeetupDate(_ isoDate: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: isoDate) else { return isoDate }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "EEEE, MMMM d, yyyy"
        return output.string(from: date)
    }

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(meetup.sport)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)

                    Text(meetup.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Hosted by \(meetup.hostName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    if let desc = meetup.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                    }

                    Label(formatMeetupDate(meetup.date), systemImage: "calendar")
                    Label(formatMeetupTime(meetup.time), systemImage: "clock")

                    if let location = meetup.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                }

                // Skill levels
                if let levels = meetup.skillLevels, !levels.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Skill Levels")
                            .font(.headline)
                        HStack(spacing: 6) {
                            ForEach(levels, id: \.self) { level in
                                Text(level)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                // Participants section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Players (\(meetup.participantCount)/\(meetup.playerLimit ?? 10))")
                        .font(.headline)

                    ProgressView(value: Double(meetup.participantCount), total: Double(meetup.playerLimit ?? 10))
                        .tint(.orange)

                    if isLoadingParticipants {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.8)
                            Text("Loading players...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if !participants.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(participants) { participant in
                                    Button(action: { selectedParticipant = participant }) {
                                        VStack(spacing: 4) {
                                            ZStack(alignment: .topTrailing) {
                                                if let pictureData = participant.profilePicture,
                                                   let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                                                   let uiImage = UIImage(data: imageData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 52, height: 52)
                                                        .clipShape(Circle())
                                                } else {
                                                    Circle()
                                                        .fill(
                                                            LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                        )
                                                        .frame(width: 52, height: 52)
                                                        .overlay(
                                                            Text(participant.displayName.prefix(1).uppercased())
                                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                                .foregroundColor(.white)
                                                        )
                                                }

                                                if participant.id == meetup.hostId {
                                                    Circle()
                                                        .fill(Color.orange)
                                                        .frame(width: 16, height: 16)
                                                        .overlay(
                                                            Image(systemName: "star.fill")
                                                                .font(.system(size: 8))
                                                                .foregroundColor(.white)
                                                        )
                                                }
                                            }

                                            Text(participant.displayName.components(separatedBy: " ").first ?? participant.displayName)
                                                .font(.caption2)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .frame(width: 56)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Group chat button — appears once 2+ players join
                if meetup.participantCount >= 2 && (isJoined || isHost) {
                    Button(action: { showGroupChat = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.subheadline)
                            Text("Group Chat")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(20)
                    }
                }

                Divider()

                // Action
                HStack {
                    Spacer()
                    if isHost {
                        Button(action: { showCancelConfirm = true }) {
                            Text("Cancel Meetup")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(20)
                        }
                        .alert("Cancel Meetup", isPresented: $showCancelConfirm) {
                            Button("Yes, Cancel", role: .destructive) {
                                Task {
                                    await viewModel.cancelMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                    dismiss()
                                }
                            }
                            Button("No", role: .cancel) {}
                        } message: {
                            Text("Are you sure you want to cancel this meetup?")
                        }
                    } else if isJoined {
                        Button(action: {
                            Task {
                                await viewModel.leaveMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                dismiss()
                            }
                        }) {
                            Text("Leave Meetup")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .cornerRadius(20)
                        }
                    } else if !meetup.isFull {
                        Button(action: {
                            Task {
                                await viewModel.joinMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                dismiss()
                            }
                        }) {
                            Text("Join Meetup")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(20)
                        }
                    } else {
                        Text("This meetup is full")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .navigationTitle("Meetup Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let token = authViewModel.getToken() else { return }
            // Use cached participants if still fresh
            if let cached = MeetupParticipantsCache.shared.participants(for: meetup.id) {
                participants = cached
                return
            }
            isLoadingParticipants = true
            if let response = try? await MeetupService.shared.getParticipants(token: token, meetupId: meetup.id) {
                participants = response.participants
                MeetupParticipantsCache.shared.store(response.participants, for: meetup.id)
            }
            isLoadingParticipants = false
        }
        .sheet(item: $selectedParticipant) { participant in
            NavigationView {
                ParticipantProfileSheet(user: participant)
                    .environmentObject(authViewModel)
                    .navigationTitle(participant.displayName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { selectedParticipant = nil }
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
            }
        }
        .sheet(isPresented: $showGroupChat) {
            MeetupChatView(meetupId: meetup.id, meetupTitle: meetup.title)
                .environmentObject(authViewModel)
        }
    }
}

struct ParticipantProfileSheet: View {
    let user: User
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var pokeStatus: ParticipantPokeStatus = .notPoked
    @State private var existingMatchId: String?
    @State private var existingMatchPartnerName: String?
    @State private var showChat = false

    private enum ParticipantPokeStatus { case notPoked, loading, poked, matched }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Avatar header
                ZStack {
                    if let pictureData = user.profilePicture,
                       let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 260)
                            .clipped()
                    } else {
                        LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 260)
                            .overlay(
                                Text(user.displayName.prefix(1).uppercased())
                                    .font(.system(size: 80, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        if let year = user.collegeYear {
                            Text(year)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let major = user.major, !major.isEmpty {
                            Text(major)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let sports = user.sports, !sports.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sports) { sport in
                                    HStack(spacing: 4) {
                                        Text(sportEmoji(sport.sport))
                                        Text(sport.sport)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(sport.skillLevel)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.secondarySystemBackground))
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(16)
                                }
                            }
                        }
                    }

                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Action button — hidden for own profile
                    if user.id != (authViewModel.user?.id ?? "") {
                        if pokeStatus == .matched {
                            Button { showChat = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("Message")
                                        .font(.headline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .padding(.top, 8)
                        } else {
                            Button {
                                guard pokeStatus == .notPoked else { return }
                                Task { await pokeParticipant() }
                            } label: {
                                HStack(spacing: 10) {
                                    if pokeStatus == .loading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: pokeStatus == .notPoked ? "hand.point.right.fill" : "checkmark")
                                            .font(.system(size: 18, weight: .bold))
                                    }
                                    Text(pokeStatus == .poked ? "Poked" : "Poke")
                                        .font(.headline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    pokeStatus == .notPoked || pokeStatus == .loading
                                        ? LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .shadow(color: (pokeStatus == .poked ? Color.green : Color.orange).opacity(0.3),
                                        radius: 8, x: 0, y: 4)
                            }
                            .disabled(pokeStatus == .poked || pokeStatus == .loading)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(20)
            }
        }
        .task { await checkRelationshipStatus() }
        .sheet(isPresented: $showChat) {
            if let matchId = existingMatchId, let partnerName = existingMatchPartnerName {
                ChatView(matchId: matchId, partnerName: partnerName)
                    .environmentObject(authViewModel)
            }
        }
    }

    @MainActor
    private func checkRelationshipStatus() async {
        let currentUserId = authViewModel.user?.id ?? ""
        guard user.id != currentUserId else { return }

        // Fast path: use in-memory cache populated by MatchViewModel (runs every 5s)
        if let matchInfo = RelationshipStatusCache.shared.matchInfo(for: user.id) {
            existingMatchId = matchInfo.matchId
            existingMatchPartnerName = matchInfo.partnerName
            pokeStatus = .matched
            return
        }
        if RelationshipStatusCache.shared.isPoked(user.id) {
            pokeStatus = .poked
        }
    }

    @MainActor
    private func pokeParticipant() async {
        guard let token = authViewModel.getToken() else { return }
        pokeStatus = .loading
        do {
            let response = try await MatchService.shared.poke(token: token, userId: user.id)
            if response.status == "matched" {
                existingMatchId = response.match?.id
                existingMatchPartnerName = response.match?.partnerName ?? user.displayName
                pokeStatus = .matched
                if let m = response.match {
                    RelationshipStatusCache.shared.populateMatches([m])
                }
            } else {
                pokeStatus = .poked
                RelationshipStatusCache.shared.markPoked(user.id)
            }
        } catch {
            pokeStatus = .notPoked
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
