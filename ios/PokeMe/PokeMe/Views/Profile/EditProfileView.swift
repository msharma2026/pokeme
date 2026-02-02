import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var displayName: String = ""
    @State private var major: String = ""
    @State private var bio: String = ""
    @State private var instagram: String = ""
    @State private var twitter: String = ""
    @State private var snapchat: String = ""
    @State private var linkedin: String = ""

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?

    var body: some View {
        NavigationView {
            Form {
                // Profile Picture Section
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let pictureData = authViewModel.user?.profilePicture,
                                      let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                                      let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.blue.gradient)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(displayName.prefix(1).uppercased())
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text("Change Photo")
                                    .font(.caption)
                            }
                        }
                        Spacer()
                    }
                }

                // Basic Info
                Section("Basic Info") {
                    TextField("Display Name", text: $displayName)
                    TextField("Major", text: $major)
                }

                // Bio
                Section("Bio") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                }

                // Social Links
                Section("Social Media") {
                    HStack {
                        Image(systemName: "camera")
                            .foregroundColor(.pink)
                            .frame(width: 24)
                        TextField("Instagram username", text: $instagram)
                    }
                    HStack {
                        Image(systemName: "bird")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("Twitter/X username", text: $twitter)
                    }
                    HStack {
                        Image(systemName: "message")
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                        TextField("Snapchat username", text: $snapchat)
                    }
                    HStack {
                        Image(systemName: "briefcase")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        TextField("LinkedIn username", text: $linkedin)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                loadCurrentValues()
            }
            .onChange(of: selectedPhoto) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            profileImage = uiImage
                            await uploadPhoto(data: data)
                        }
                    }
                }
            }
        }
    }

    private func loadCurrentValues() {
        if let user = authViewModel.user {
            displayName = user.displayName
            major = user.major ?? ""
            bio = user.bio ?? ""
            instagram = user.socials?.instagram ?? ""
            twitter = user.socials?.twitter ?? ""
            snapchat = user.socials?.snapchat ?? ""
            linkedin = user.socials?.linkedin ?? ""
        }
    }

    private func saveProfile() async {
        let socials = Socials(
            instagram: instagram.isEmpty ? nil : instagram,
            twitter: twitter.isEmpty ? nil : twitter,
            snapchat: snapchat.isEmpty ? nil : snapchat,
            linkedin: linkedin.isEmpty ? nil : linkedin
        )

        if let updatedUser = await viewModel.updateProfile(
            token: authViewModel.getToken(),
            displayName: displayName,
            major: major.isEmpty ? nil : major,
            bio: bio.isEmpty ? nil : bio,
            socials: socials
        ) {
            authViewModel.user = updatedUser
            dismiss()
        }
    }

    private func uploadPhoto(data: Data) async {
        // Compress image
        if let image = UIImage(data: data),
           let compressedData = image.jpegData(compressionQuality: 0.5) {
            if let updatedUser = await viewModel.uploadProfilePicture(
                token: authViewModel.getToken(),
                imageData: compressedData
            ) {
                authViewModel.user = updatedUser
            }
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
