import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showEmailLogin = false

    private var token: String? {
        get { UserDefaults.standard.string(forKey: Constants.StorageKeys.authToken) }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: Constants.StorageKeys.authToken)
            } else {
                UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.authToken)
            }
        }
    }

    init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        if let savedToken = token {
            Task {
                await loadUser(token: savedToken)
            }
        }
    }

    private func loadUser(token: String) async {
        do {
            let user = try await AuthService.shared.getMe(token: token)
            self.user = user
            self.isAuthenticated = true
        } catch {
            self.token = nil
            self.isAuthenticated = false
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.login(email: email, password: password)
            token = response.token
            user = response.user
            isAuthenticated = true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func register(email: String, password: String, displayName: String, major: String?) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.register(
                email: email,
                password: password,
                displayName: displayName,
                major: major
            )
            token = response.token
            user = response.user
            isAuthenticated = true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        token = nil
        user = nil
        isAuthenticated = false
        showEmailLogin = false
    }

    func getToken() -> String? {
        return token
    }

    func handlePhoneLogin(token: String, user: User) {
        self.token = token
        self.user = user
        self.isAuthenticated = true
    }
}
