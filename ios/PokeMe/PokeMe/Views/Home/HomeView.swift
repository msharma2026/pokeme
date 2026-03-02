import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var pokesViewModel = PokesViewModel()
    @StateObject private var matchViewModel = MatchViewModel()
    @StateObject private var messageNotificationPoller = MessageNotificationPoller()
    @State private var selectedTab = 0

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

            ProfileView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .tint(.orange)
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
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
