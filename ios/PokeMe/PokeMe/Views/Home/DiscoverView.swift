import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DiscoverViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sport filter chips with emojis
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", emoji: "🔥", isSelected: viewModel.selectedSport == nil) {
                            viewModel.selectedSport = nil
                            Task { await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user) }
                        }

                        ForEach(Sport.allCases, id: \.self) { sport in
                            FilterChip(
                                label: sport.rawValue,
                                emoji: sportEmoji(sport.rawValue),
                                isSelected: viewModel.selectedSport == sport.rawValue
                            ) {
                                viewModel.selectedSport = sport.rawValue
                                Task { await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                ZStack(alignment: .top) {
                    stateContent

                    if viewModel.newProfilesAvailable {
                        newPeoplePill
                    }
                }
                .animation(.spring(response: 0.4), value: viewModel.newProfilesAvailable)
            }
            .refreshable {
                await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user)
            }
            .navigationTitle("Discover")
            .task {
                if viewModel.profiles.isEmpty {
                    await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user)
                }
                viewModel.startBackgroundPolling(token: authViewModel.getToken(), currentUser: authViewModel.user)
            }
            .onDisappear {
                viewModel.stopBackgroundPolling()
            }
            .onChange(of: authViewModel.user?.id) { _ in
                Task {
                    await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user)
                }
            }
            .alert("It's a Match! 🎉", isPresented: $viewModel.showMatchAlert) {
                Button("Start Chatting!") {}
            } message: {
                if let user = viewModel.matchedUser {
                    Text("You and \(user.displayName) both want to play! Head to Matches to start chatting.")
                }
            }
        }
    }

    private var newPeoplePill: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35)) {
                viewModel.applyPendingProfiles()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("New people available")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .cornerRadius(25)
            .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private var stateContent: some View {
        if let error = viewModel.errorMessage {
            errorView(error)
        } else if viewModel.isLoading {
            loadingView
        } else if viewModel.profiles.isEmpty {
            emptyView
        } else {
            profilesView
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.linearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task { await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(20)
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
            Text("Finding players...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.orange.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.linearGradient(colors: [.orange, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Text("No more profiles")
                .font(.title2)
                .fontWeight(.bold)
            Text("Check back later for new players!")
                .foregroundColor(.secondary)
            // Primary CTA
            Button(action: {
                Task { await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user) }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh").fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(25)
                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            // Secondary CTA
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToProfile"), object: nil)
            }) {
                Text("Complete profile for better matches")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .underline()
            }
            Spacer()
        }
    }

    private var profilesView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.profiles.enumerated()), id: \.element.id) { index, profile in
                        DiscoverCardView(
                            user: profile,
                            isPoked: viewModel.pokedIds.contains(profile.id),
                            onPoke: {
                                Task { await viewModel.pokeProfile(token: authViewModel.getToken(), user: profile) }
                            },
                            onSkip: {
                                let nextIndex = index + 1
                                guard nextIndex < viewModel.profiles.count else { return }
                                withAnimation(Theme.Anim.spring) {
                                    proxy.scrollTo(viewModel.profiles[nextIndex].id, anchor: .top)
                                }
                            }
                        )
                        .containerRelativeFrame(.vertical)
                        .id(profile.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
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

struct FilterChip: View {
    let label: String
    var emoji: String = ""
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 14))
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .shadow(color: isSelected ? .orange.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
