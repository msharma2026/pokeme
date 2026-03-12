import SwiftUI

struct MeetupCardView: View {
    let meetup: Meetup
    let currentUserId: String
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onCancel: () -> Void

    private var isHost: Bool { meetup.hostId == currentUserId }
    private var isJoined: Bool { meetup.participants?.contains(currentUserId) ?? false }

    @State private var showCancelConfirm = false

    private func formatMeetupDate(_ isoDate: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: isoDate) else { return isoDate }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "EEE, M/d"
        return output.string(from: date)
    }

    private func formatMeetupTime(_ hhmm: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "HH:mm"
        guard let date = input.date(from: hhmm) else { return hhmm }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "h:mm a"
        return output.string(from: date)
    }

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
                Label(formatMeetupDate(meetup.date), systemImage: "calendar")
                    .font(.caption)
                Label(formatMeetupTime(meetup.time), systemImage: "clock")
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
                    Button(action: { showCancelConfirm = true }) {
                        Text("Cancel Meetup")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    .alert("Cancel Meetup", isPresented: $showCancelConfirm) {
                        Button("Yes, Cancel", role: .destructive) { onCancel() }
                        Button("No", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to cancel this meetup?")
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
