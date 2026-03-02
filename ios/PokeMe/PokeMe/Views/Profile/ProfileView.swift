import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false

    // Collapsible section state
    @State private var sportsExpanded = true
    @State private var availabilityExpanded = true
    @State private var bioExpanded = true
    @State private var socialsExpanded = true

    // MARK: - Profile Completeness

    private var completenessScore: Int {
        guard let user = authViewModel.user else { return 0 }
        var score = 0
        if !user.displayName.isEmpty { score += 10 }
        if user.profilePicture != nil { score += 20 }
        if let bio = user.bio, !bio.isEmpty { score += 15 }
        if let sports = user.sports, sports.count >= 2 { score += 15 }
        else if let sports = user.sports, !sports.isEmpty { score += 8 }
        if let avail = user.availability, !avail.isEmpty { score += 15 }
        if let major = user.major, !major.isEmpty { score += 10 }
        if let socials = user.socials {
            let filled = [socials.instagram, socials.twitter, socials.snapchat, socials.linkedin]
                .contains { $0 != nil && !($0?.isEmpty ?? true) }
            if filled { score += 10 }
        }
        if user.collegeYear != nil { score += 5 }
        return min(score, 100)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Gradient header
                    ZStack {
                        LinearGradient(
                            colors: [.orange, .pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 200)

                        VStack {
                            Spacer()
                            Wave()
                                .fill(Color(uiColor: .systemBackground))
                                .frame(height: 40)
                        }

                        profilePictureWithRing
                            .offset(y: 40)
                    }
                    .frame(height: 200)

                    VStack(spacing: 20) {
                        userInfoSection
                            .padding(.top, 50)

                        if let sports = authViewModel.user?.sports, !sports.isEmpty {
                            collapsibleSection(
                                title: "Sports",
                                icon: "trophy.fill",
                                gradient: [.orange, .pink],
                                isExpanded: $sportsExpanded
                            ) {
                                sportsContent(sports: sports)
                            }
                        }

                        if let availability = authViewModel.user?.availability, !availability.isEmpty {
                            collapsibleSection(
                                title: "Availability",
                                icon: "calendar",
                                gradient: [.green, .teal],
                                isExpanded: $availabilityExpanded
                            ) {
                                availabilityContent(availability: availability)
                            }
                        }

                        if let bio = authViewModel.user?.bio, !bio.isEmpty {
                            collapsibleSection(
                                title: "About",
                                icon: "quote.bubble.fill",
                                gradient: [.purple, .indigo],
                                isExpanded: $bioExpanded
                            ) {
                                Text(bio)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let socials = authViewModel.user?.socials {
                            collapsibleSection(
                                title: "Socials",
                                icon: "at",
                                gradient: [.blue, .cyan],
                                isExpanded: $socialsExpanded
                            ) {
                                socialsContent(socials: socials)
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showEditProfile = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authViewModel)
            }
        }
    }

    // MARK: - Profile Picture with Completeness Ring

    private var profilePictureWithRing: some View {
        ZStack {
            // Background track ring
            Circle()
                .stroke(Color(uiColor: .systemGray4), lineWidth: 4)
                .frame(width: 136, height: 136)

            // Completeness arc
            Circle()
                .trim(from: 0, to: CGFloat(completenessScore) / 100)
                .stroke(
                    LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 136, height: 136)
                .rotationEffect(.degrees(-90))

            // White border
            Circle()
                .fill(Color(uiColor: .systemBackground))
                .frame(width: 126, height: 126)

            // Profile picture
            profilePictureContent

            // Completeness badge (bottom-right)
            if completenessScore < 100 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(completenessScore)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(10)
                            .offset(x: 4, y: 4)
                    }
                }
                .frame(width: 136, height: 136)
            }
        }
    }

    private var profilePictureContent: some View {
        Group {
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
                    .fill(
                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text(authViewModel.user?.displayName.prefix(1).uppercased() ?? "?")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    // MARK: - User Info

    private var userInfoSection: some View {
        VStack(spacing: 8) {
            Text(authViewModel.user?.displayName ?? "Unknown")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            if let year = authViewModel.user?.collegeYear {
                Text(year)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
            }

            if let major = authViewModel.user?.major {
                HStack {
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(.purple)
                    Text(major)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            // Completeness nudge if < 80%
            if completenessScore < 80 {
                Button(action: { showEditProfile = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Complete your profile to get more matches")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Collapsible Section Container

    private func collapsibleSection<Content: View>(
        title: String,
        icon: String,
        gradient: [Color],
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable header
            Button(action: {
                withAnimation(Theme.Anim.standard) { isExpanded.wrappedValue.toggle() }
            }) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.headline)
                        .foregroundStyle(
                            .linearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                        )
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                Divider()
                    .padding(.horizontal)

                content()
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(Theme.Radius.card)
    }

    // MARK: - Section Content

    private func sportsContent(sports: [SportEntry]) -> some View {
        VStack(spacing: 10) {
            ForEach(sports) { sport in
                HStack {
                    Text(sportEmoji(sport.sport))
                        .font(.title3)
                    Text(sport.sport)
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                    Text(sport.skillLevel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(colors: skillGradient(sport.skillLevel), startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func availabilityContent(availability: [String: [String]]) -> some View {
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let dayAbbrs = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let timeSlots = ["Morning", "Afternoon", "Evening"]

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 70, alignment: .leading)
                ForEach(dayAbbrs, id: \.self) { abbr in
                    Text(abbr)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)

            ForEach(timeSlots, id: \.self) { slot in
                HStack(spacing: 0) {
                    Text(slot)
                        .font(.caption)
                        .frame(width: 70, alignment: .leading)
                        .foregroundColor(.secondary)

                    ForEach(Array(zip(days, dayAbbrs)), id: \.0) { day, _ in
                        let isAvailable = availability[day]?.contains(slot) ?? false
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                isAvailable
                                    ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color(uiColor: .systemGray4), Color(uiColor: .systemGray4)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(height: 28)
                            .overlay(
                                isAvailable ? Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                : nil
                            )
                            .padding(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func socialsContent(socials: Socials) -> some View {
        HStack(spacing: 12) {
            if let instagram = socials.instagram, !instagram.isEmpty {
                socialBadge(icon: "camera.fill", label: instagram, colors: [.pink, .purple, .orange])
            }
            if let twitter = socials.twitter, !twitter.isEmpty {
                socialBadge(icon: "at", label: twitter, colors: [.blue, .cyan])
            }
            if let snapchat = socials.snapchat, !snapchat.isEmpty {
                socialBadge(icon: "message.fill", label: snapchat, colors: [.yellow, .green])
            }
            if let linkedin = socials.linkedin, !linkedin.isEmpty {
                socialBadge(icon: "briefcase.fill", label: linkedin, colors: [.blue, .indigo])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func socialBadge(icon: String, label: String, colors: [Color]) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.linearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("@\(label)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(colors.first?.opacity(0.1) ?? Color.clear)
        .cornerRadius(20)
    }

    // MARK: - Helpers

    private func sportEmoji(_ sport: String) -> String {
        switch sport.lowercased() {
        case "basketball": return "🏀"
        case "tennis": return "🎾"
        case "soccer": return "⚽"
        case "volleyball": return "🏐"
        case "badminton": return "🏸"
        case "running": return "🏃"
        case "swimming": return "🏊"
        case "cycling": return "🚴"
        case "table tennis": return "🏓"
        case "football": return "🏈"
        case "baseball": return "⚾"
        case "golf": return "⛳"
        case "hiking": return "🥾"
        case "yoga": return "🧘"
        case "rock climbing": return "🧗"
        default: return "🏅"
        }
    }

    private func skillGradient(_ level: String) -> [Color] {
        switch level.lowercased() {
        case "beginner": return [.green, .mint]
        case "intermediate": return [.blue, .cyan]
        case "advanced": return [.orange, .red]
        default: return [.gray, .gray]
        }
    }
}

// Wavy shape for profile header
struct Wave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h * 0.5))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.5),
            control1: CGPoint(x: w * 0.3, y: -h * 0.3),
            control2: CGPoint(x: w * 0.7, y: h * 1.3)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
