import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var major = ""
    @State private var bio = ""
    @State private var instagram = ""
    @State private var twitter = ""
    @State private var snapchat = ""
    @State private var linkedin = ""
    @State private var selectedYear: String = ""
    @State private var sports: [SportEntry] = []
    @State private var availability: [String: [String]] = [:]

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var showPhotoSizeAlert = false

    // For adding a sport
    @State private var showAddSport = false
    @State private var newSport = Sport.basketball
    @State private var newSkillLevel = SkillLevel.beginner

    // For adding specific hours
    @State private var showHourPicker = false

    private let timeSlots = ["Morning", "Afternoon", "Evening"]
    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let dayAbbreviations = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationView {
            Form {
                // Profile Picture
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
                    Picker("College Year", selection: $selectedYear) {
                        Text("Select").tag("")
                        ForEach(CollegeYear.allCases, id: \.self) { year in
                            Text(year.rawValue).tag(year.rawValue)
                        }
                    }
                    TextField("Major", text: $major)
                }

                // Sports
                Section("Sports") {
                    ForEach(sports) { sport in
                        HStack {
                            Text(sport.sport)
                            Spacer()
                            Text(sport.skillLevel)
                                .foregroundColor(.secondary)
                            Button(action: {
                                sports.removeAll { $0.sport == sport.sport }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button(action: { showAddSport = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Sport")
                        }
                    }
                }

                // Availability Calendar Grid
                Section("Availability") {
                    VStack(spacing: 0) {
                        // Header row with day abbreviations
                        HStack(spacing: 0) {
                            Text("")
                                .frame(width: 70, alignment: .leading)
                            ForEach(dayAbbreviations, id: \.self) { abbr in
                                Text(abbr)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 6)

                        // Row for each time slot
                        ForEach(timeSlots, id: \.self) { slot in
                            HStack(spacing: 0) {
                                Text(slot)
                                    .font(.caption)
                                    .frame(width: 70, alignment: .leading)
                                    .foregroundColor(.secondary)

                                ForEach(Array(zip(days, dayAbbreviations)), id: \.0) { day, _ in
                                    let isSelected = availability[day]?.contains(slot) ?? false
                                    Button(action: {
                                        toggleAvailability(day: day, slot: slot)
                                    }) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSelected ? Color.blue : Color(.systemGray5))
                                            .frame(height: 36)
                                            .overlay(
                                                isSelected ? Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                                : nil
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(2)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Custom hour entries
                    let customHours = getCustomHourEntries()
                    if !customHours.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            ForEach(customHours, id: \.day) { entry in
                                HStack {
                                    Text(entry.day)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(entry.display)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(action: {
                                        removeCustomHours(day: entry.day)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }

                    Button(action: { showHourPicker = true }) {
                        HStack {
                            Image(systemName: "clock.badge.plus")
                                .foregroundColor(.blue)
                            Text("Add specific hours")
                                .font(.subheadline)
                        }
                    }
                    .padding(.top, 4)
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
                            let resized = resizeImage(uiImage, maxDimension: 400)
                            if let compressed = resized.jpegData(compressionQuality: 0.7),
                               compressed.count > 500_000 {
                                showPhotoSizeAlert = true
                                return
                            }
                            profileImage = uiImage
                            await uploadPhoto(data: data)
                        }
                    }
                }
            }
            .alert("Photo Too Large", isPresented: $showPhotoSizeAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please choose a smaller image (under 2 MB). Try a lower-resolution photo or a cropped version.")
            }
            .sheet(isPresented: $showAddSport) {
                addSportSheet
            }
            .sheet(isPresented: $showHourPicker) {
                HourPickerSheet(availability: $availability)
            }
        }
    }

    private var addSportSheet: some View {
        NavigationView {
            Form {
                Picker("Sport", selection: $newSport) {
                    ForEach(Sport.allCases, id: \.self) { sport in
                        Text(sport.rawValue).tag(sport)
                    }
                }

                Picker("Skill Level", selection: $newSkillLevel) {
                    ForEach(SkillLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }
            .navigationTitle("Add Sport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showAddSport = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let entry = SportEntry(sport: newSport.rawValue, skillLevel: newSkillLevel.rawValue)
                        if !sports.contains(where: { $0.sport == entry.sport }) {
                            sports.append(entry)
                        }
                        showAddSport = false
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }

    private func toggleAvailability(day: String, slot: String) {
        var daySlots = availability[day] ?? []
        if daySlots.contains(slot) {
            daySlots.removeAll { $0 == slot }
        } else {
            daySlots.append(slot)
        }
        availability[day] = daySlots.isEmpty ? nil : daySlots
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
            selectedYear = user.collegeYear ?? ""
            sports = user.sports ?? []
            availability = user.availability ?? [:]
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
            socials: socials,
            sports: sports.isEmpty ? nil : sports,
            collegeYear: selectedYear.isEmpty ? nil : selectedYear,
            availability: availability.isEmpty ? nil : availability
        ) {
            authViewModel.user = updatedUser
            dismiss()
        }
    }

    private func uploadPhoto(data: Data) async {
        if let image = UIImage(data: data) {
            let resized = resizeImage(image, maxDimension: 400)
            if let compressedData = resized.jpegData(compressionQuality: 0.7) {
                if let updatedUser = await viewModel.uploadProfilePicture(
                    token: authViewModel.getToken(),
                    imageData: compressedData
                ) {
                    authViewModel.user = updatedUser
                }
            }
        }
    }

    private struct CustomHourEntry: Identifiable {
        let day: String
        let display: String
        var id: String { day }
    }

    private func getCustomHourEntries() -> [CustomHourEntry] {
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var entries: [CustomHourEntry] = []
        for day in days {
            guard let slots = availability[day] else { continue }
            let customHours = slots.compactMap { AvailabilityHelper.parseHour($0) }
            if !customHours.isEmpty {
                let ranges = AvailabilityHelper.groupHoursIntoRanges(customHours)
                entries.append(CustomHourEntry(day: day, display: ranges.joined(separator: ", ")))
            }
        }
        return entries
    }

    private func removeCustomHours(day: String) {
        guard var slots = availability[day] else { return }
        slots.removeAll { AvailabilityHelper.parseHour($0) != nil }
        availability[day] = slots.isEmpty ? nil : slots
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
