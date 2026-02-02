import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showEditProfile = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Picture
                    profilePictureSection

                    // User Info
                    userInfoSection

                    // Bio
                    if let bio = authViewModel.user?.bio, !bio.isEmpty {
                        bioSection(bio: bio)
                    }

                    // Socials
                    if let socials = authViewModel.user?.socials {
                        socialsSection(socials: socials)
                    }

                    // Stats
                    statsSection

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showEditProfile = true
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(authViewModel)
            }
        }
    }

    private var profilePictureSection: some View {
        VStack {
            if let pictureData = authViewModel.user?.profilePicture,
               let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text(authViewModel.user?.displayName.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    private var userInfoSection: some View {
        VStack(spacing: 8) {
            Text(authViewModel.user?.displayName ?? "Unknown")
                .font(.title)
                .fontWeight(.bold)

            if let major = authViewModel.user?.major {
                HStack {
                    Image(systemName: "book.closed")
                    Text(major)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            if let email = authViewModel.user?.email {
                HStack {
                    Image(systemName: "envelope")
                    Text(email)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if let phone = authViewModel.user?.phone {
                HStack {
                    Image(systemName: "phone")
                    Text(phone)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    private func bioSection(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(bio)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func socialsSection(socials: Socials) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Socials")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                if let instagram = socials.instagram, !instagram.isEmpty {
                    socialBadge(icon: "camera", label: instagram, color: .pink)
                }
                if let twitter = socials.twitter, !twitter.isEmpty {
                    socialBadge(icon: "bird", label: twitter, color: .blue)
                }
                if let snapchat = socials.snapchat, !snapchat.isEmpty {
                    socialBadge(icon: "message", label: snapchat, color: .yellow)
                }
                if let linkedin = socials.linkedin, !linkedin.isEmpty {
                    socialBadge(icon: "briefcase", label: linkedin, color: .blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func socialBadge(icon: String, label: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text("@\(label)")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(20)
    }

    private var statsSection: some View {
        HStack(spacing: 32) {
            VStack {
                Text("\(authViewModel.user?.socialPoints ?? 0)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
