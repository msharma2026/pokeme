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
    @State private var showDeleteAccountConfirm = false

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
                    NavigationLink(destination: BlockedUsersView()) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.indigo)
                            Text("Blocked Users")
                                .foregroundColor(.primary)
                        }
                    }
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
                    Button(action: { showDeleteAccountConfirm = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Account")
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
            .alert("Delete Account?", isPresented: $showDeleteAccountConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await authViewModel.deleteAccount() }
                }
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
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

struct BlockedUsersView: View {
    @State private var blockedMatches: [Match] = []
    private let blockedMatchesKey = "blockedMatchesArchive"

    var body: some View {
        Group {
            if blockedMatches.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "hand.raised.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No blocked users")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(blockedMatches) { match in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 46, height: 46)
                                if let data = match.partnerProfilePicture,
                                   let imageData = Data(base64Encoded: data.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 42, height: 42)
                                        .clipShape(Circle())
                                        .grayscale(1)
                                } else {
                                    Text(match.partnerName.prefix(1).uppercased())
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.partnerName)
                                    .font(.headline)
                                Text("Blocked")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                unblock(id: match.id)
                            } label: {
                                Label("Unblock", systemImage: "hand.raised.slash")
                            }
                            .tint(.green)
                        }
                        .contextMenu {
                            Button {
                                unblock(id: match.id)
                            } label: {
                                Label("Unblock", systemImage: "hand.raised.slash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadBlocked() }
    }

    private func loadBlocked() {
        if let data = UserDefaults.standard.data(forKey: blockedMatchesKey),
           let items = try? JSONDecoder().decode([Match].self, from: data) {
            blockedMatches = items
        }
    }

    private func unblock(id: String) {
        withAnimation {
            blockedMatches.removeAll { $0.id == id }
        }
        if let data = try? JSONEncoder().encode(blockedMatches) {
            UserDefaults.standard.set(data, forKey: blockedMatchesKey)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
