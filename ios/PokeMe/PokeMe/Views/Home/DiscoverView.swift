import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = DiscoverViewModel()
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var showPokeFeedback = false
    @State private var showSkipFeedback = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.orange.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

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

                    if let error = viewModel.errorMessage {
                        Spacer()
                        VStack(spacing: 12) {
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
                        }
                        Spacer()
                    } else if viewModel.isLoading {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.orange)
                            Text("Finding players...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    } else if let profile = viewModel.currentProfile {
                        ZStack {
                            if showPokeFeedback {
                                Text("POKED!")
                                    .font(.system(size: 48, weight: .black, design: .rounded))
                                    .foregroundColor(.green)
                                    .rotationEffect(.degrees(-15))
                                    .opacity(0.8)
                                    .zIndex(10)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            if showSkipFeedback {
                                Text("SKIP")
                                    .font(.system(size: 48, weight: .black, design: .rounded))
                                    .foregroundColor(.red)
                                    .rotationEffect(.degrees(15))
                                    .opacity(0.8)
                                    .zIndex(10)
                                    .transition(.scale.combined(with: .opacity))
                            }

                            ScrollView {
                                DiscoverCardView(
                                    user: profile,
                                    onPoke: { pokeWithAnimation() },
                                    onSkip: { skipWithAnimation() }
                                )
                                .padding(.vertical, 8)
                            }
                            .offset(cardOffset)
                            .rotationEffect(.degrees(cardRotation))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        cardOffset = value.translation
                                        cardRotation = Double(value.translation.width / 20)
                                    }
                                    .onEnded { value in
                                        if value.translation.width > 120 {
                                            pokeWithAnimation()
                                        } else if value.translation.width < -120 {
                                            skipWithAnimation()
                                        } else {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                cardOffset = .zero
                                                cardRotation = 0
                                            }
                                        }
                                    }
                            )
                        }
                    } else {
                        Spacer()
                        VStack(spacing: 16) {
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

                            Button(action: {
                                Task { await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user) }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(25)
                                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Discover")
            .task {
                await viewModel.fetchProfiles(token: authViewModel.getToken(), currentUser: authViewModel.user)
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

    private func pokeWithAnimation() {
        withAnimation(.easeIn(duration: 0.15)) {
            showPokeFeedback = true
        }
        withAnimation(.easeIn(duration: 0.3)) {
            cardOffset = CGSize(width: 500, height: 0)
            cardRotation = 15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task { await viewModel.pokeCurrentProfile(token: authViewModel.getToken()) }
            showPokeFeedback = false
            cardOffset = .zero
            cardRotation = 0
        }
    }

    private func skipWithAnimation() {
        withAnimation(.easeIn(duration: 0.15)) {
            showSkipFeedback = true
        }
        withAnimation(.easeIn(duration: 0.3)) {
            cardOffset = CGSize(width: -500, height: 0)
            cardRotation = -15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.skipCurrentProfile()
            showSkipFeedback = false
            cardOffset = .zero
            cardRotation = 0
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
