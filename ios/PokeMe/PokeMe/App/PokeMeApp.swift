import SwiftUI
import UserNotifications

@main
struct PokeMeApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("appearanceMode") private var appearanceMode: String = "System"

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    init() {
        UserDefaults.standard.register(defaults: ["notificationsEnabled": true])
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    if authViewModel.needsOnboarding {
                        OnboardingView()
                            .environmentObject(authViewModel)
                    } else {
                        HomeView()
                            .environmentObject(authViewModel)
                    }
                } else if authViewModel.showEmailLogin {
                    LoginView()
                        .environmentObject(authViewModel)
                } else {
                    PhoneLoginView()
                        .environmentObject(authViewModel)
                }
            }
            .preferredColorScheme(colorScheme)
            .onAppear {
                NotificationManager.shared.requestAuthorizationIfNeeded()
            }
        }
    }
}
