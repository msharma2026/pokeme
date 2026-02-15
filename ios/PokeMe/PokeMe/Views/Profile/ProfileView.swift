import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Gradient header with profile picture
                    ZStack {
                        LinearGradient(
                            colors: [.orange, .pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 200)

                        // Wavy bottom edge
                        VStack {
                            Spacer()
                            Wave()
                                .fill(Color(.systemBackground))
                                .frame(height: 40)
                        }

                        profilePictureSection
                            .offset(y: 40)
                    }
                    .frame(height: 200)

                    VStack(spacing: 20) {
                        userInfoSection
                            .padding(.top, 50)

                        if let sports = authViewModel.user?.sports, !sports.isEmpty {
                            sportsSection(sports: sports)
                        }

                        if let availability = authViewModel.user?.availability, !availability.isEmpty {
                            availabilitySection(availability: availability)
                        }

                        if let bio = authViewModel.user?.bio, !bio.isEmpty {
                            bioSection(bio: bio)
                        }

                        if let socials = authViewModel.user?.socials {
                            socialsSection(socials: socials)
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

    private var profilePictureSection: some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 130, height: 130)

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
        }
    }

    private func sportsSection(sports: [SportEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sports", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(
                    .linearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                )

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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func availabilitySection(availability: [String: [String]]) -> some View {
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let dayAbbrs = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let timeSlots = ["Morning", "Afternoon", "Evening"]

        return VStack(alignment: .leading, spacing: 10) {
            Label("Availability", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(
                    .linearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
                )

            VStack(spacing: 0) {
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
                                        : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray4)], startPoint: .top, endPoint: .bottom)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func bioSection(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About", systemImage: "quote.bubble.fill")
                .font(.headline)
                .foregroundStyle(
                    .linearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                )
            Text(bio)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func socialsSection(socials: Socials) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Socials", systemImage: "at")
                .font(.headline)
                .foregroundStyle(
                    .linearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                )

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
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
