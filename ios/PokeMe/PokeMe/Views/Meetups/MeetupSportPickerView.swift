import SwiftUI

struct MeetupSportPickerView: View {
    let onSelect: (String?) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("What do you want to play?")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Find a meetup or host your own")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    // All Meetups option
                    Button(action: { onSelect(nil) }) {
                        HStack(spacing: 12) {
                            Text("🔥")
                                .font(.system(size: 28))
                            Text("All Meetups")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            LinearGradient(colors: [.orange.opacity(0.15), .pink.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                    }
                    .foregroundColor(.primary)

                    // Sport grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Sport.allCases, id: \.self) { sport in
                            Button(action: { onSelect(sport.rawValue) }) {
                                VStack(spacing: 8) {
                                    Text(sportEmoji(sport.rawValue))
                                        .font(.system(size: 36))
                                    Text(sport.rawValue.capitalized)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Meetups")
            .navigationBarTitleDisplayMode(.inline)
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
}
