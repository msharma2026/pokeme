import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var pokesViewModel = PokesViewModel()
    @StateObject private var matchViewModel = MatchViewModel()
    @StateObject private var meetupViewModel = MeetupViewModel()
    @State private var selectedTab = 0  // default to Meetups
    @State private var dragOffset: CGFloat = 0

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
                let h = geo.size.height

                HStack(spacing: 0) {
                    MeetupsListView()
                        .environmentObject(authViewModel)
                        .environmentObject(meetupViewModel)
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
                    ScheduleView()
                        .environmentObject(authViewModel)
                        .environmentObject(matchViewModel)
                        .environmentObject(meetupViewModel)
                        .frame(width: w)
                    ProfileView()
                        .environmentObject(authViewModel)
                        .frame(width: w)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(x: -CGFloat(selectedTab) * w + dragOffset)

                // Left edge strip — absolutely positioned so it always sits at the
                // real screen left edge regardless of HStack width.
                Color.clear
                    .frame(width: 20, height: h)
                    .contentShape(Rectangle())
                    .position(x: 10, y: h / 2)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                guard abs(dx) > abs(dy) * 1.2 else { return }
                                dragOffset = selectedTab == 0 ? dx * 0.3 : dx
                            }
                            .onEnded { value in
                                let predicted = value.predictedEndTranslation.width
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    if predicted > w * 0.3 { selectedTab = max(selectedTab - 1, 0) }
                                    dragOffset = 0
                                }
                            }
                    )

                // Right edge strip — positioned at the real screen right edge.
                Color.clear
                    .frame(width: 20, height: h)
                    .contentShape(Rectangle())
                    .position(x: w - 10, y: h / 2)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                guard abs(dx) > abs(dy) * 1.2 else { return }
                                dragOffset = selectedTab == 5 ? dx * 0.3 : dx
                            }
                            .onEnded { value in
                                let predicted = value.predictedEndTranslation.width
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    if predicted < -w * 0.3 { selectedTab = min(selectedTab + 1, 5) }
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
            await meetupViewModel.fetchMeetups(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id)
            await matchViewModel.prefetchAllMessages(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id)
        }
        .onAppear {
            matchViewModel.startPolling(token: authViewModel.getToken())
            meetupViewModel.startPolling(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id)
        }
        .onDisappear {
            matchViewModel.stopPolling()
            meetupViewModel.stopPolling()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshMeetups"), object: nil)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                matchViewModel.startPolling(token: authViewModel.getToken())
                meetupViewModel.startPolling(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id)
            } else if phase == .background {
                matchViewModel.stopPolling()
                meetupViewModel.stopPolling()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToDiscover"))) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedTab = 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToProfile"))) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedTab = 5 }
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
            tabBarItem(4, icon: "calendar",         activeIcon: "calendar",             label: "Schedule")
            tabBarItem(5, icon: "person",           activeIcon: "person.fill",          label: "Profile")
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
