import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var pokesViewModel = PokesViewModel()
    @State private var selectedTab = 0

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

            ProfileView()
                .environmentObject(authViewModel)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(3)
        }
        .tint(.orange)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
