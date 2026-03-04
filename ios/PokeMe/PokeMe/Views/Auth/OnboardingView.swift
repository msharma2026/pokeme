import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()

    @State private var step = 0
    @State private var goingForward = true

    // Photo
    @State private var photoItem: PhotosPickerItem?
    @State private var profileUIImage: UIImage?
    @State private var profileImageData: Data?

    // About
    @State private var selectedYear = ""
    @State private var bio = ""

    // Sports
    @State private var sports: [SportEntry] = []
    @State private var pendingSport: String?
    @State private var showSkillPicker = false

    // Availability
    @State private var availability: [String: [String]] = [:]

    private let days: [(abbr: String, full: String)] = [
        ("Mon", "Monday"), ("Tue", "Tuesday"), ("Wed", "Wednesday"),
        ("Thu", "Thursday"), ("Fri", "Friday"), ("Sat", "Saturday"), ("Sun", "Sunday")
    ]
    private let slots = ["Morning", "Afternoon", "Evening"]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                if step > 0 { navBar }

                ZStack {
                    switch step {
                    case 0: welcomeStep
                    case 1: photoStep
                    case 2: aboutStep
                    case 3: sportsStep
                    default: availabilityStep
                    }
                }
                .id(step)
                .animation(.easeInOut(duration: 0.25), value: step)

                Spacer(minLength: 0)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
        .confirmationDialog(
            "Skill level for \(pendingSport ?? "")?",
            isPresented: $showSkillPicker,
            titleVisibility: .visible
        ) {
            Button("Beginner")     { addSport(skill: "Beginner") }
            Button("Intermediate") { addSport(skill: "Intermediate") }
            Button("Advanced")     { addSport(skill: "Advanced") }
            Button("Cancel", role: .cancel) { pendingSport = nil }
        }
        .onChange(of: photoItem) { _ in
            Task {
                guard let item = photoItem,
                      let data = try? await item.loadTransferable(type: Data.self) else { return }
                profileImageData = data
                profileUIImage = UIImage(data: data)
            }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                    .foregroundColor(.primary)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...4, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.orange : Color(.systemGray4))
                        .frame(width: i == step ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: step)
                }
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        if step == 0 {
            Button(action: advance) {
                HStack(spacing: 8) {
                    Text("Get Started").fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        } else {
            HStack(spacing: 12) {
                Button("Skip", action: advance)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                Button(action: advance) {
                    HStack(spacing: 6) {
                        Text(step == 4 ? "Finish!" : "Next").fontWeight(.semibold)
                        Image(systemName: step == 4 ? "checkmark" : "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }
        }
    }

    // MARK: - Navigation

    private func advance() {
        goingForward = true
        if step < 4 {
            withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
        } else {
            finishOnboarding()
        }
    }

    private func goBack() {
        guard step > 0 else { return }
        goingForward = false
        withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
    }

    private func addSport(skill: String) {
        guard let name = pendingSport else { return }
        sports.removeAll { $0.sport == name }
        sports.append(SportEntry(sport: name, skillLevel: skill))
        pendingSport = nil
    }

    private func finishOnboarding() {
        Task {
            let token = authViewModel.getToken()

            // Upload photo if selected
            if let uiImage = profileUIImage {
                let maxDim: CGFloat = 400
                let scale = min(1.0, min(maxDim / uiImage.size.width, maxDim / uiImage.size.height))
                let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let resized = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
                if let jpegData = resized.jpegData(compressionQuality: 0.7) {
                    _ = await profileVM.uploadProfilePicture(token: token, imageData: jpegData)
                }
            }

            // Save profile fields
            let current = authViewModel.user
            if let updated = await profileVM.updateProfile(
                token: token,
                displayName: current?.displayName ?? "",
                major: current?.major,
                bio: bio.isEmpty ? nil : bio,
                socials: nil,
                sports: sports.isEmpty ? nil : sports,
                collegeYear: selectedYear.isEmpty ? nil : selectedYear,
                availability: availability.isEmpty ? nil : availability
            ) {
                authViewModel.user = updated
            }

            authViewModel.needsOnboarding = false
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.orange.opacity(0.2), .pink.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 140)
                Text("🏅").font(.system(size: 72))
            }
            VStack(spacing: 12) {
                Text("Welcome, \(authViewModel.user?.displayName.components(separatedBy: " ").first ?? "Athlete")!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Let's set up your profile so we can find the best playing partners for you.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - Step 1: Photo

    private var photoStep: some View {
        VStack(spacing: 28) {
            stepHeader(icon: "camera.fill", title: "Profile Photo", subtitle: "Help others recognize you on the court")

            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.orange.opacity(0.15), .pink.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 150, height: 150)

                    if let image = profileUIImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                            Text("Tap to add photo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .shadow(color: .orange.opacity(0.2), radius: 12, x: 0, y: 6)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: About You

    private var aboutStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                stepHeader(icon: "person.fill", title: "About You", subtitle: "Help others get to know you")

                // College Year
                VStack(alignment: .leading, spacing: 10) {
                    Label("College Year", systemImage: "graduationcap.fill").font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(CollegeYear.allCases, id: \.rawValue) { year in
                            Button(action: { selectedYear = selectedYear == year.rawValue ? "" : year.rawValue }) {
                                Text(year.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedYear == year.rawValue ? .semibold : .regular)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        selectedYear == year.rawValue
                                            ? LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundColor(selectedYear == year.rawValue ? .white : .primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }

                // Bio
                VStack(alignment: .leading, spacing: 10) {
                    Label("Bio", systemImage: "text.quote").font(.headline)
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 110)
                        if bio.isEmpty {
                            Text("Tell people about your athletic interests...")
                                .foregroundColor(Color(.placeholderText))
                                .font(.subheadline)
                                .padding(12)
                        }
                        TextEditor(text: $bio)
                            .font(.subheadline)
                            .padding(8)
                            .background(Color.clear)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                    }
                    Text("\(bio.count)/250")
                        .font(.caption2)
                        .foregroundColor(bio.count > 240 ? .orange : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .onChange(of: bio) { _ in if bio.count > 250 { bio = String(bio.prefix(250)) } }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
    }

    // MARK: - Step 3: Sports

    private var sportsStep: some View {
        VStack(spacing: 12) {
            stepHeader(icon: "sportscourt.fill", title: "Your Sports", subtitle: "Select everything you play")
                .padding(.horizontal, 24)

            // Selected sport tags
            if !sports.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sports, id: \.sport) { entry in
                            HStack(spacing: 5) {
                                Text(sportEmoji(entry.sport)).font(.caption)
                                Text(entry.sport).font(.caption).fontWeight(.medium)
                                Text("·").font(.caption).foregroundColor(.white.opacity(0.6))
                                Text(entry.skillLevel).font(.caption2).foregroundColor(.white.opacity(0.9))
                                Button(action: { sports.removeAll { $0.sport == entry.sport } }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            // Sport grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(Sport.allCases, id: \.self) { sport in
                        let isSelected = sports.contains(where: { $0.sport == sport.rawValue })
                        Button(action: {
                            if isSelected {
                                sports.removeAll { $0.sport == sport.rawValue }
                            } else {
                                pendingSport = sport.rawValue
                                showSkillPicker = true
                            }
                        }) {
                            VStack(spacing: 6) {
                                Text(sportEmoji(sport.rawValue)).font(.system(size: 28))
                                Text(sport.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(isSelected ? .white : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                isSelected
                                    ? LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Step 4: Availability

    private var availabilityStep: some View {
        VStack(spacing: 12) {
            stepHeader(icon: "calendar", title: "Your Schedule", subtitle: "When are you free to play?")
                .padding(.horizontal, 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    // Column headers
                    HStack(spacing: 6) {
                        Text("").frame(width: 44)
                        ForEach(slots, id: \.self) { slot in
                            VStack(spacing: 2) {
                                Text(slotEmoji(slot)).font(.system(size: 14))
                                Text(slot).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)

                    Divider().padding(.horizontal, 24)

                    // Day rows
                    ForEach(days, id: \.full) { day in
                        HStack(spacing: 6) {
                            Text(day.abbr)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 44, alignment: .leading)

                            ForEach(slots, id: \.self) { slot in
                                let isOn = availability[day.full]?.contains(slot) == true
                                Button(action: { toggleSlot(day: day.full, slot: slot) }) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isOn
                                                ? LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .frame(height: 40)
                                        .overlay(
                                            Image(systemName: isOn ? "checkmark" : "plus")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(isOn ? .white : Color(.systemGray3))
                                        )
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
        }
    }

    private func toggleSlot(day: String, slot: String) {
        if availability[day]?.contains(slot) == true {
            availability[day]?.removeAll { $0 == slot }
            if availability[day]?.isEmpty == true { availability.removeValue(forKey: day) }
        } else {
            availability[day, default: []].append(slot)
        }
    }

    // MARK: - Shared Helpers

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func sportEmoji(_ sport: String) -> String {
        switch sport.lowercased() {
        case "basketball":   return "🏀"
        case "tennis":       return "🎾"
        case "soccer":       return "⚽"
        case "volleyball":   return "🏐"
        case "badminton":    return "🏸"
        case "running":      return "🏃"
        case "swimming":     return "🏊"
        case "cycling":      return "🚴"
        case "table tennis": return "🏓"
        case "football":     return "🏈"
        case "baseball":     return "⚾"
        case "golf":         return "⛳"
        case "hiking":       return "🥾"
        case "yoga":         return "🧘"
        case "rock climbing":return "🧗"
        default:             return "🏅"
        }
    }

    private func slotEmoji(_ slot: String) -> String {
        switch slot {
        case "Morning":   return "🌅"
        case "Afternoon": return "☀️"
        case "Evening":   return "🌙"
        default:          return ""
        }
    }
}
