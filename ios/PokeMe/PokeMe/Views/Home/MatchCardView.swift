import SwiftUI

struct DiscoverCardView: View {
    let user: User
    let onPoke: () -> Void
    let onSkip: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Profile picture with gradient overlay
            ZStack(alignment: .bottomLeading) {
                if let pictureData = user.profilePicture,
                   let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 340)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 340)
                        .overlay(
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.system(size: 90, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }

                // Gradient overlay at bottom for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)

                // Name overlay on image
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if let year = user.collegeYear {
                        Text(year)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                }
                .padding(16)
            }

            VStack(spacing: 14) {
                // Sports with colorful badges
                if let sports = user.sports, !sports.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sports) { sport in
                                HStack(spacing: 4) {
                                    Text(sportEmoji(sport.sport))
                                    Text(sport.sport)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(sport.skillLevel)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    LinearGradient(
                                        colors: sportGradient(sport.sport),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .opacity(0.15)
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                }

                // Availability Calendar Grid
                if let availability = user.availability, !availability.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Availability")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                        let dayAbbrs = ["M", "T", "W", "T", "F", "S", "S"]
                        let timeSlots = ["Morning", "Afternoon", "Evening"]

                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Text("")
                                    .frame(width: 55, alignment: .leading)
                                ForEach(Array(dayAbbrs.enumerated()), id: \.offset) { _, abbr in
                                    Text(abbr)
                                        .font(.system(size: 10, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.bottom, 2)

                            ForEach(timeSlots, id: \.self) { slot in
                                HStack(spacing: 0) {
                                    Text(slot)
                                        .font(.system(size: 9))
                                        .frame(width: 55, alignment: .leading)
                                        .foregroundColor(.secondary)

                                    ForEach(days, id: \.self) { day in
                                        let isAvailable = availability[day]?.contains(slot) ?? false
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                isAvailable
                                                    ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                                                    : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray5)], startPoint: .top, endPoint: .bottom)
                                            )
                                            .frame(height: 22)
                                            .padding(1)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Bio
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Action buttons
                HStack(spacing: 20) {
                    // Skip button with animation
                    Button(action: onSkip) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 64, height: 64)
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                                .frame(width: 64, height: 64)
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }

                    Spacer()

                    // Poke button with pulse animation
                    Button(action: onPoke) {
                        ZStack {
                            // Pulse rings
                            Circle()
                                .stroke(Color.orange.opacity(0.2), lineWidth: 2)
                                .frame(width: 80, height: 80)
                                .scaleEffect(pulseScale)
                                .opacity(2 - pulseScale)

                            Circle()
                                .fill(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 70, height: 70)
                                .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)

                            Image(systemName: "hand.point.right.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .scaleEffect(appeared ? 1.0 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.4
            }
        }
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

    private func sportGradient(_ sport: String) -> [Color] {
        switch sport.lowercased() {
        case "basketball": return [.orange, .red]
        case "tennis": return [.green, .yellow]
        case "soccer": return [.green, .mint]
        case "volleyball": return [.yellow, .orange]
        case "badminton": return [.blue, .cyan]
        case "running": return [.red, .pink]
        case "swimming": return [.blue, .cyan]
        case "cycling": return [.purple, .pink]
        case "table tennis": return [.red, .orange]
        case "football": return [.brown, .orange]
        case "baseball": return [.red, .blue]
        case "golf": return [.green, .teal]
        case "hiking": return [.brown, .green]
        case "yoga": return [.purple, .indigo]
        case "rock climbing": return [.gray, .orange]
        default: return [.blue, .purple]
        }
    }
}
