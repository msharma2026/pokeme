import SwiftUI

private struct SportCategory {
    let name: String
    let sports: [Sport]
}

private let sportCategories: [SportCategory] = [
    SportCategory(name: "Popular", sports: [.basketball, .soccer, .volleyball, .tennis, .running]),
    SportCategory(name: "Racket", sports: [.tennis, .badminton, .tabletennis]),
    SportCategory(name: "Team", sports: [.basketball, .soccer, .volleyball, .football, .baseball]),
    SportCategory(name: "Fitness & Outdoor", sports: [.running, .swimming, .cycling, .yoga, .hiking, .rockclimbing, .golf]),
]

struct MeetupSportPickerView: View {
    let onSelect: (String?) -> Void

    @State private var searchText = ""

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var filteredCategories: [SportCategory] {
        if searchText.isEmpty { return sportCategories }
        return sportCategories.compactMap { category in
            let matched = category.sports.filter {
                $0.rawValue.lowercased().contains(searchText.lowercased())
            }
            return matched.isEmpty ? nil : SportCategory(name: category.name, sports: matched)
        }
    }

    private var flatFilteredSports: [Sport] {
        if searchText.isEmpty { return [] }
        return Sport.allCases.filter {
            $0.rawValue.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Text("What do you want to play?")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Find a meetup or host your own")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search sport or meetup", text: $searchText)
                            .font(.body)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // All Meetups option (hidden when searching)
                    if searchText.isEmpty {
                        Button(action: { onSelect(nil) }) {
                            HStack(spacing: 12) {
                                Text("🔥")
                                    .font(.system(size: 28))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("All Meetups")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text("Browse everything happening now")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
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
                    }

                    // Categories
                    if searchText.isEmpty {
                        ForEach(sportCategories, id: \.name) { category in
                            categorySection(category)
                        }
                    } else if flatFilteredSports.isEmpty {
                        Text("No sports match \"\(searchText)\"")
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(flatFilteredSports, id: \.self) { sport in
                                sportTile(sport: sport)
                            }
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

    // MARK: - Sub-views

    private func categorySection(_ category: SportCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 6) {
                Text(category.name)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(category.sports, id: \.self) { sport in
                    sportTile(sport: sport)
                }
            }
        }
    }

    private func sportTile(sport: Sport) -> some View {
        Button(action: { onSelect(sport.rawValue) }) {
            VStack(spacing: 6) {
                Text(sportEmoji(sport.rawValue))
                    .font(.system(size: 32))
                Text(sport.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(sportTileBackground(sport.rawValue))
            .cornerRadius(14)
        }
        .foregroundColor(.primary)
    }

    private func sportTileBackground(_ sport: String) -> some View {
        let colors = sportGradient(sport)
        return LinearGradient(
            colors: colors.map { $0.opacity(0.12) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
