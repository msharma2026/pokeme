import SwiftUI

struct DiscoverCardView: View {
    let user: User
    let isPoked: Bool
    let onPoke: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var showBio = false
    @State private var showWhySheet = false
    @State private var showActions = false
    @State private var showComingSoon = false
    @State private var comingSoonFeature = ""

    var body: some View {
        VStack(spacing: 0) {
            // ── Photo ── reduced height so card is less image-dominant
            ZStack(alignment: .bottom) {
                if let pictureData = user.profilePicture,
                   let imageData = Data(base64Encoded: pictureData.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 240)
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
                        .frame(height: 240)
                        .overlay(
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.system(size: 80, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }

                // Gradient scrim
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // ── 1. Header row: name + year ──
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if let year = user.collegeYear {
                            Text(year)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                        }
                    }
                    Spacer()
                }
                .padding(14)
            }
            .frame(height: 240)
            // ── Action menu button (top-right) ──
            .overlay(alignment: .topTrailing) {
                Button(action: { showActions = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(12)
            }

            // ── Content section ──
            VStack(spacing: 12) {

                // ── 2. Compatibility strip (tappable → Why sheet) ──
                if let score = user.recommendationScore {
                    Button(action: { showWhySheet = true }) {
                        compatibilityStrip(score: score, reasons: user.recommendationReasons ?? [])
                    }
                    .buttonStyle(.plain)
                }

                // ── 3. Sports chips ──
                if let sports = user.sports, !sports.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sports) { sport in
                                HStack(spacing: 4) {
                                    Text(sportEmoji(sport.sport))
                                        .font(.system(size: 13))
                                    Text(sport.sport)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(sport.skillLevel)
                                        .font(.caption2)
                                        .foregroundColor(.primary.opacity(0.7))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .cornerRadius(6)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    LinearGradient(
                                        colors: sportGradient(sport.sport),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .opacity(0.14)
                                )
                                .cornerRadius(14)
                            }
                        }
                    }
                }

                // ── 4. Availability (condensed) ──
                if let availability = user.availability, !availability.isEmpty {
                    condensedAvailability(availability: availability)
                }

                // ── 5. Bio (expandable) ──
                if let bio = user.bio, !bio.isEmpty {
                    bioToggle(bio: bio)
                }

                // ── Primary CTA: Poke ──
                pokeButton

                // ── Secondary actions row ──
                HStack {
                    if user.recommendationScore != nil {
                        Button(action: { showWhySheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                Text("Why this match?")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button(action: onSkip) {
                        HStack(spacing: 4) {
                            Text("Skip")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            .padding(16)

            Spacer(minLength: 0)
        }
        .background(Color(uiColor: .systemBackground))
        .scaleEffect(appeared ? 1.0 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                appeared = true
            }
        }
        // ── Why this match? sheet ──
        .sheet(isPresented: $showWhySheet) {
            whyMatchSheet
        }
        // ── Action menu ──
        .confirmationDialog("Profile options", isPresented: $showActions, titleVisibility: .hidden) {
            Button("Hide this profile") {
                comingSoonFeature = "Hiding profiles"
                showComingSoon = true
            }
            Button("Report", role: .destructive) {
                comingSoonFeature = "Reporting"
                showComingSoon = true
            }
            Button("Block", role: .destructive) {
                comingSoonFeature = "Blocking"
                showComingSoon = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Coming Soon", isPresented: $showComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(comingSoonFeature) will be available in an upcoming update.")
        }
    }

    // MARK: - Compatibility Strip

    private func compatibilityStrip(score: Double, reasons: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(Int(score.rounded()))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(
                    .linearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Match")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Compatibility")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 4) {
                    CircleProgress(value: score / 100)
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            if !reasons.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(reasons.prefix(2)), id: \.self) { reason in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text(reason)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.pink.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(14)
    }

    // MARK: - Condensed Availability

    private func condensedAvailability(availability: [String: [String]]) -> some View {
        let days: [String] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let dayAbbrs: [String] = ["M", "T", "W", "T", "F", "S", "S"]
        let slots: [String] = ["Morning", "Afternoon", "Evening"]

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Availability")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    Text("").frame(width: 46, alignment: .leading)
                    ForEach(Array(dayAbbrs.enumerated()), id: \.offset) { _, abbr in
                        Text(abbr)
                            .font(.system(size: 9, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.secondary)
                    }
                }
                ForEach(slots, id: \.self) { slot in
                    HStack(spacing: 0) {
                        Text(slot)
                            .font(.system(size: 8))
                            .frame(width: 46, alignment: .leading)
                            .foregroundColor(.secondary)
                        ForEach(days, id: \.self) { day in
                            let isAvailable = availability[day]?.contains(slot) ?? false
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    isAvailable
                                        ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(colors: [Color(uiColor: .systemGray5), Color(uiColor: .systemGray5)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(height: 18)
                                .padding(1.5)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bio Toggle

    private func bioToggle(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { withAnimation(Theme.Anim.spring) { showBio.toggle() } }) {
                HStack {
                    Text(showBio ? "Hide bio" : "Read bio")
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: showBio ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.secondary)
            }
            if showBio {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Poke Button

    private var pokeButton: some View {
        Button(action: isPoked ? {} : onPoke) {
            HStack(spacing: 10) {
                Image(systemName: isPoked ? "checkmark" : "hand.point.right.fill")
                    .font(.system(size: 18, weight: .bold))
                Text(isPoked ? "Poked!" : "Poke")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                isPoked
                    ? LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .cornerRadius(20)
            .shadow(color: (isPoked ? Color.green : Color.orange).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isPoked)
        .padding(.top, 4)
    }

    // MARK: - Why This Match? Sheet

    private var whyMatchSheet: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall score
                    if let score = user.recommendationScore {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.orange)
                                Text("\(Int(score.rounded()))% Match")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        .linearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                    )
                            }
                            Text("with \(user.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            CircleProgress(value: score / 100)
                                .frame(width: 64, height: 64)
                                .padding(.top, 4)
                        }
                        .padding(.top, 8)
                    }

                    // Breakdown bars
                    if let breakdown = user.recommendationBreakdown, !breakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Score Breakdown")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(scoreBreakdownItems(breakdown), id: \.label) { item in
                                breakdownRow(item)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(16)
                    }

                    // Shared reasons
                    if let reasons = user.recommendationReasons, !reasons.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What you have in common")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(reasons, id: \.self) { reason in
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(reason)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .systemGray6))
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .navigationTitle("Why This Match?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showWhySheet = false }
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Score Breakdown Helpers

    private struct ScoreBreakdownItem {
        let label: String
        let score: Double
        let maxScore: Double
        let icon: String
        let color: Color
    }

    private func scoreBreakdownItems(_ breakdown: [String: Double]) -> [ScoreBreakdownItem] {
        let map: [(key: String, label: String, max: Double, icon: String, color: Color)] = [
            ("sports", "Shared Sports", 55, "figure.run", .orange),
            ("availability", "Availability Overlap", 20, "calendar", .green),
            ("year", "Same Year", 10, "graduationcap.fill", .blue),
            ("major_bio", "Similar Interests", 15, "brain.head.profile", .purple),
        ]
        return map.compactMap { item in
            guard let score = breakdown[item.key] else { return nil }
            return ScoreBreakdownItem(label: item.label, score: score, maxScore: item.max, icon: item.icon, color: item.color)
        }
    }

    private func breakdownRow(_ item: ScoreBreakdownItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(item.color)
                    .frame(width: 20)
                Text(item.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(item.score.rounded()))/\(Int(item.maxScore))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: item.score, total: item.maxScore)
                .tint(item.color)
        }
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

// MARK: - Circular progress arc

struct CircleProgress: View {
    let value: Double // 0.0 – 1.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .systemGray5), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(
                    LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}
