import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Environment(\.dismiss) var dismiss
    @State private var showResetConfirm = false
    @State private var resetResult: String?
    @State private var isResetting = false

    var body: some View {
        NavigationView {
            List {
                // Appearance
                Section {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }
                    .tint(.orange)
                } header: {
                    Label("Appearance", systemImage: "paintbrush.fill")
                        .foregroundStyle(
                            .linearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                        )
                }

                // Notifications
                Section {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .tint(.orange)
                } header: {
                    Label("Notifications", systemImage: "bell.fill")
                        .foregroundStyle(
                            .linearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                }

                // Account
                Section {
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Log Out")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Label("Account", systemImage: "person.fill")
                        .foregroundStyle(
                            .linearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                        )
                }

                // Testing
                Section {
                    Button(action: {
                        showResetConfirm = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.orange)
                            Text("Reset Pokes & Matches")
                                .foregroundColor(.primary)
                            Spacer()
                            if isResetting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isResetting)

                    if let result = resetResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("Testing", systemImage: "hammer.fill")
                        .foregroundStyle(
                            .linearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                        )
                } footer: {
                    Text("Clears all your pokes and matches so you can re-discover users.")
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Made with")
                        Spacer()
                        Text("SwiftUI")
                            .foregroundStyle(
                                .linearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .fontWeight(.medium)
                    }
                } header: {
                    Label("About", systemImage: "info.circle.fill")
                        .foregroundStyle(
                            .linearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
                        )
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            .alert("Reset Test Data?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task {
                        await resetData()
                    }
                }
            } message: {
                Text("This will delete all your pokes and matches. You'll be able to discover and poke users again.")
            }
        }
    }

    private func resetData() async {
        guard let token = UserDefaults.standard.string(forKey: Constants.StorageKeys.authToken) else { return }
        isResetting = true
        do {
            let response = try await MatchService.shared.resetTestData(token: token)
            resetResult = "Deleted \(response.deletedPokes) pokes, \(response.deletedMatches) matches"
        } catch {
            resetResult = "Error: \(error.localizedDescription)"
        }
        isResetting = false
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
