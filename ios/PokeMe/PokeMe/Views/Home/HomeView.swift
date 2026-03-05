import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var pokesViewModel = PokesViewModel()
    @StateObject private var matchViewModel = MatchViewModel()
@State private var selectedTab = 0  // default to Meetups
    @State private var dragOffset: CGFloat = 0
    @State private var dragCommitted = false

    private var unreadMatchCount: Int {
        let userId = authViewModel.user?.id ?? ""
        return matchViewModel.matches.filter {
            $0.lastMessage != nil && $0.lastMessage?.senderId != userId
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let w = geo.size.width
                HStack(spacing: 0) {
                    MeetupsListView()
                        .environmentObject(authViewModel)
                        .frame(width: w)
                    DiscoverView()
                        .environmentObject(authViewModel)
                        .frame(width: w)
                    IncomingPokesView(viewModel: pokesViewModel)
                        .environmentObject(authViewModel)
                        .frame(width: w)
                    MatchesListView()
                        .environmentObject(authViewModel)
                        .frame(width: w)
                    ProfileView()
                        .environmentObject(authViewModel)
                        .frame(width: w)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(x: -CGFloat(selectedTab) * w + dragOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // Commit to horizontal direction only
                            if !dragCommitted {
                                guard abs(dx) > abs(dy) * 1.5, abs(dx) > 12 else { return }
                                dragCommitted = true
                            }
                            // Rubber-band at the edges
                            if selectedTab == 0 && dx > 0 {
                                dragOffset = dx * 0.3
                            } else if selectedTab == 4 && dx < 0 {
                                dragOffset = dx * 0.3
                            } else {
                                dragOffset = dx
                            }
                        }
                        .onEnded { value in
                            dragCommitted = false
                            let predicted = value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if predicted < -w * 0.3 {
                                    selectedTab = min(selectedTab + 1, 4)
                                } else if predicted > w * 0.3 {
                                    selectedTab = max(selectedTab - 1, 0)
                                }
                                dragOffset = 0
                            }
                        }
                )
            }

            tabBar
        }
        .task {
            await matchViewModel.fetchMatches(token: authViewModel.getToken())
            await matchViewModel.fetchGroupChats(token: authViewModel.getToken())
        }
        .onAppear {
            matchViewModel.startPolling(token: authViewModel.getToken())
        }
        .onDisappear {
            matchViewModel.stopPolling()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshMeetups"), object: nil)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Restart pollers after app returns from background
                matchViewModel.startPolling(token: authViewModel.getToken())
            } else if phase == .background {
                matchViewModel.stopPolling()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToDiscover"))) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedTab = 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToProfile"))) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedTab = 4 }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(0, icon: "person.3",        activeIcon: "person.3.fill",        label: "Meetups")
            tabBarItem(1, icon: "sportscourt",      activeIcon: "sportscourt.fill",     label: "Discover")
            tabBarItem(2, icon: "hand.point.right", activeIcon: "hand.point.right.fill",label: "Pokes",
                       badge: pokesViewModel.pokeCount > 0 ? pokesViewModel.pokeCount : nil)
            tabBarItem(3, icon: "message",          activeIcon: "message.fill",         label: "Matches",
                       badge: unreadMatchCount > 0 ? unreadMatchCount : nil)
            tabBarItem(4, icon: "person",           activeIcon: "person.fill",          label: "Profile")
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
        .overlay(Divider(), alignment: .top)
    }

    @ViewBuilder
    private func tabBarItem(_ index: Int, icon: String, activeIcon: String, label: String, badge: Int? = nil) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedTab = index
                dragOffset = 0
            }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: selectedTab == index ? activeIcon : icon)
                        .font(.system(size: 22))
                        .frame(width: 28, height: 28)
                    if let badge {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.red, in: Capsule())
                            .offset(x: 10, y: -6)
                    }
                }
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundStyle(selectedTab == index ? .orange : Color(.systemGray))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
