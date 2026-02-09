import SwiftUI

struct MatchesListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MatchViewModel()
    @State private var selectedMatch: Match?
    @State private var animateEmpty = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.orange)
                        Text("Loading matches...")
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.matches.isEmpty {
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
                    }
                    .padding()
                    .onAppear { animateEmpty = true }
                } else {
                    List(viewModel.matches) { match in
                        Button(action: {
                            selectedMatch = match
                        }) {
                            MatchRow(match: match, currentUserId: authViewModel.user?.id ?? "")
                        }
                    }
                    .listStyle(.plain)
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
        }
    }
}

struct MatchRow: View {
    let match: Match
    let currentUserId: String

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with gradient border
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 56, height: 56)

                if let pictureData = match.partnerProfilePicture,
                   let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(match.partnerName.prefix(1).uppercased())
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    .linearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(match.partnerName)
                        .font(.headline)

                    if let sports = match.partnerSports, !sports.isEmpty {
                        Text(sportEmoji(sports.first?.sport ?? ""))
                            .font(.caption)
                    }
                }

                if let lastMessage = match.lastMessage {
                    Text(lastMessage.text)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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

            if let lastMessage = match.lastMessage {
                Text(formatTime(lastMessage.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date: Date?
        date = formatter.date(from: isoString)

        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }

        guard let date = date else { return "" }

        let displayFormatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            displayFormatter.timeStyle = .short
        } else {
            displayFormatter.dateStyle = .short
        }
        return displayFormatter.string(from: date)
    }
}
