import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var pokesViewModel = PokesViewModel()
    @StateObject private var matchViewModel = MatchViewModel()
    @StateObject private var messageNotificationPoller = MessageNotificationPoller()
    @State private var selectedTab = 1  // default to Discover

    /// Matches where partner sent the last message — proxy for unread chats
    private var unreadMatchCount: Int {
        let userId = authViewModel.user?.id ?? ""
        return matchViewModel.matches.filter {
            $0.lastMessage != nil && $0.lastMessage?.senderId != userId
        }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MeetupsListView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "person.3.fill" : "person.3")
                    Text("Meetups")
                }
                .tag(0)

            DiscoverView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "sportscourt.fill" : "sportscourt")
                    Text("Discover")
                }
                .tag(1)

            IncomingPokesView(viewModel: pokesViewModel)
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "hand.point.right.fill" : "hand.point.right")
                    Text("Pokes")
                }
                .tag(2)
                .badge(pokesViewModel.pokeCount)

            MatchesListView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "message.fill" : "message")
                    Text("Matches")
                }
                .tag(3)
                .badge(unreadMatchCount > 0 ? unreadMatchCount : 0)

            ProfileView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .tint(.orange)
        .simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    guard abs(h) > abs(v) * 1.5 else { return }
                    withAnimation {
                        if h < 0 { selectedTab = min(selectedTab + 1, 4) }
                        else      { selectedTab = max(selectedTab - 1, 0) }
                    }
                }
        )
        .task {
            await matchViewModel.fetchMatches(token: authViewModel.getToken())
        }
        .onAppear {
            matchViewModel.startPolling(token: authViewModel.getToken())
        }
        .onDisappear {
            matchViewModel.stopPolling()
            messageNotificationPoller.stopPolling()
        }
        // Handle tab-switch notifications from empty state CTAs
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToDiscover"))) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToProfile"))) { _ in
            selectedTab = 4
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
