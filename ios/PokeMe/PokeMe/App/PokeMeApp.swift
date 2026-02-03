import SwiftUI

@main
struct PokeMeApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    HomeView()
                        .environmentObject(authViewModel)
                } else if authViewModel.showEmailLogin {
                    LoginView()
                        .environmentObject(authViewModel)
                } else {
                    PhoneLoginView()
                        .environmentObject(authViewModel)
                }
            }
            .onAppear {
                NotificationManager.shared.requestAuthorizationIfNeeded()
            }
        }
    }
}
