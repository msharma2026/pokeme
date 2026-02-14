import SwiftUI

struct MeetupCardView: View {
    let meetup: Meetup
    let currentUserId: String
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onCancel: () -> Void

    private var isHost: Bool { meetup.hostId == currentUserId }
    private var isJoined: Bool { meetup.participants?.contains(currentUserId) ?? false }

    private var sportIcon: String {
        switch meetup.sport.lowercased() {
        case "basketball": return "basketball"
        case "tennis": return "tennis.racket"
        case "soccer": return "soccerball"
        case "volleyball": return "volleyball"
        case "running": return "figure.run"
        case "swimming": return "figure.pool.swim"
        case "cycling": return "bicycle"
        case "hiking": return "figure.hiking"
        case "yoga": return "figure.yoga"
        default: return "sportscourt"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: sportIcon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(meetup.title)
                        .font(.headline)
                    Text("by \(meetup.hostName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(meetup.sport)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }

            // Date, Time, Location
            HStack(spacing: 16) {
                Label(meetup.date, systemImage: "calendar")
                    .font(.caption)
                Label(meetup.time, systemImage: "clock")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            if let location = meetup.location, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Skill badges
            if let levels = meetup.skillLevels, !levels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(levels, id: \.self) { level in
                        Text(level)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
            }

            // Player count bar
            HStack {
                let count = meetup.participantCount
                let limit = meetup.playerLimit ?? 10
                ProgressView(value: Double(count), total: Double(limit))
                    .tint(count >= limit ? .red : .orange)
                Text("\(count)/\(limit) players")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Action button
            HStack {
                Spacer()
                if isHost {
                    Button(action: onCancel) {
                        Text("Cancel Meetup")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                } else if isJoined {
                    Button(action: onLeave) {
                        Text("Leave")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                    }
                } else if !meetup.isFull {
                    Button(action: onJoin) {
                        Text("Join")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                    }
                } else {
                    Text("Full")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
