import SwiftUI

struct IncomingPokesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: PokesViewModel
    @State private var animateEmpty = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.orange)
                        Text("Loading pokes...")
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.incomingPokes.isEmpty {
                    emptyState
                } else {
                    List(viewModel.incomingPokes) { poke in
                        IncomingPokeRow(
                            poke: poke,
                            onPokeBack: {
                                Task {
                                    await viewModel.pokeBack(
                                        token: authViewModel.getToken(),
                                        userId: poke.fromUserId
                                    )
                                }
                            }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Pokes")
            .task {
                await viewModel.fetchIncomingPokes(token: authViewModel.getToken())
            }
            .onAppear {
                viewModel.startPolling(token: authViewModel.getToken())
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .alert("It's a Match!", isPresented: $viewModel.showMatchAlert) {
                Button("OK") {}
            } message: {
                if let user = viewModel.matchedUser {
                    Text("You and \(user.displayName) both want to play! Head to Matches to start chatting.")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.15), .pink.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateEmpty ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: animateEmpty
                    )

                Image(systemName: "hand.point.right.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("No pokes yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("When someone pokes you, they'll show up here!")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Helper tip
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Profiles with sports + availability are surfaced more.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 4)

            // Primary CTA
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
                .background(
                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(25)
                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            // Secondary CTA
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToProfile"), object: nil)
            }) {
                Text("Improve my profile")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .underline()
            }
        }
        .padding()
        .onAppear { animateEmpty = true }
    }
}

struct IncomingPokeRow: View {
    let poke: IncomingPoke
    let onPokeBack: () -> Void
    @State private var appeared = false

    private var isNew: Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date: Date? = formatter.date(from: poke.createdAt)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: poke.createdAt)
        }
        guard let date = date else { return false }
        return Date().timeIntervalSince(date) < 86400 // within 24 hours
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with gradient border
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                if let pictureData = poke.fromUser.profilePicture,
                   let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(poke.fromUser.displayName.prefix(1).uppercased())
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    .linearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(poke.fromUser.displayName)
                        .font(.headline)

                    // "New" badge for pokes within 24h
                    if isNew {
                        Text("New")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }
                }

                if let sports = poke.fromUser.sports, !sports.isEmpty {
                    Text(sports.map { $0.sport }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Poke Back button
            Button(action: onPokeBack) {
                Text("Poke Back")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
            }
        }
        .padding(.vertical, 4)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}
