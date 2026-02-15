import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var pokesViewModel = PokesViewModel()
    @State private var selectedTab = 0
    @StateObject private var matchViewModel = MatchViewModel()
    @StateObject private var messageNotificationPoller = MessageNotificationPoller()
    @State private var showProfile = false
    @State private var showChat = false
    @State private var currentPartnerName = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "sportscourt.fill" : "sportscourt")
                    Text("Discover")
                }
                .tag(0)

            IncomingPokesView(viewModel: pokesViewModel)
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "hand.point.right.fill" : "hand.point.right")
                    Text("Pokes")
                }
                .tag(1)
                .badge(pokesViewModel.pokeCount)

            MatchesListView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "message.fill" : "message")
                    Text("Matches")
                }
                .tag(2)

            MeetupsListView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.3.fill" : "person.3")
                    Text("Meetups")
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showChat) {
                ChatView(partnerName: currentPartnerName)
                    .environmentObject(authViewModel)
            }
            .task {
                await matchViewModel.fetchTodayMatch(token: authViewModel.getToken())
            }
            .onAppear {
                matchViewModel.startPolling(token: authViewModel.getToken())
            }
            .onDisappear {
                matchViewModel.stopPolling()
                messageNotificationPoller.stopPolling()
            }
            .onChange(of: matchViewModel.matchState) { newState in
                switch newState {
                case .matched(let match):
                    messageNotificationPoller.updateContext(matchId: match.id, partnerName: match.partnerName)
                    messageNotificationPoller.startPolling(
                        token: authViewModel.getToken(),
                        currentUserId: authViewModel.user?.id
                    )
                default:
                    messageNotificationPoller.stopPolling()
                }
            }
        }
        .tint(.orange)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
