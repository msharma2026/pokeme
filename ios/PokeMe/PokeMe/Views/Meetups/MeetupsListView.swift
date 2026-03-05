import SwiftUI

private enum MeetupQuickFilter: String, CaseIterable {
    case today = "Today"
    case beginnerFriendly = "Beginner-friendly"
    case startingSoon = "Starting soon"
}

struct MeetupsListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var viewModel: MeetupViewModel
    @State private var showCreateSheet = false
    @State private var selectedMeetup: Meetup?
    @State private var showSportPicker = true
    @State private var activeQuickFilters: Set<MeetupQuickFilter> = []

    private let sports = ["All"] + Sport.allCases.map { $0.rawValue }
    @State private var selectedSport = "All"

    // Client-side filter applied on top of server results
    private var displayedMeetups: [Meetup] {
        var result = viewModel.meetups
        if activeQuickFilters.contains(.today) {
            let today = todayDateString()
            result = result.filter { $0.date == today }
        }
        if activeQuickFilters.contains(.beginnerFriendly) {
            result = result.filter { $0.skillLevels?.contains("Beginner") ?? false }
        }
        if activeQuickFilters.contains(.startingSoon) {
            result = result.filter { isStartingSoon($0) }
        }
        return result
    }

    var body: some View {
        if showSportPicker {
            MeetupSportPickerView { sport in
                selectedSport = sport ?? "All"
                viewModel.sportFilter = sport
                Task { await viewModel.fetchMeetups(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id) }
                showSportPicker = false
            }
        } else {
            NavigationView {
                VStack(spacing: 0) {
                    // Sport filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sports, id: \.self) { sport in
                                Button(action: {
                                    selectedSport = sport
                                    viewModel.sportFilter = sport == "All" ? nil : sport
                                    Task {
                                        await viewModel.fetchMeetups(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id)
                                    }
                                }) {
                                    Text(sport)
                                        .font(.subheadline)
                                        .fontWeight(selectedSport == sport ? .semibold : .regular)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedSport == sport
                                                ? LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                                : LinearGradient(colors: [Color(uiColor: .systemGray6), Color(uiColor: .systemGray6)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .foregroundColor(selectedSport == sport ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    // Quick filter chips row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MeetupQuickFilter.allCases, id: \.self) { filter in
                                let isActive = activeQuickFilters.contains(filter)
                                Button(action: {
                                    withAnimation(Theme.Anim.quick) {
                                        if isActive {
                                            activeQuickFilters.remove(filter)
                                        } else {
                                            activeQuickFilters.insert(filter)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: quickFilterIcon(filter))
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(filter.rawValue)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isActive ? Color.orange.opacity(0.15) : Color(uiColor: .systemGray6))
                                    .foregroundColor(isActive ? .orange : .secondary)
                                    .cornerRadius(Theme.Radius.chip)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.chip)
                                            .stroke(isActive ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    // Active filter count indicator
                    if !activeQuickFilters.isEmpty {
                        HStack {
                            Text("\(displayedMeetups.count) of \(viewModel.meetups.count) meetups")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Clear filters") {
                                withAnimation(Theme.Anim.quick) { activeQuickFilters.removeAll() }
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                    }

                    // Meetups list
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading meetups...")
                        Spacer()
                    } else if displayedMeetups.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: activeQuickFilters.isEmpty ? "person.3" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(activeQuickFilters.isEmpty ? "No meetups yet" : "No meetups match filters")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(activeQuickFilters.isEmpty ? "Create one to get started!" : "Try adjusting or clearing your filters.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if !activeQuickFilters.isEmpty {
                                Button("Clear filters") {
                                    withAnimation(Theme.Anim.quick) { activeQuickFilters.removeAll() }
                                }
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(displayedMeetups) { meetup in
                                    MeetupCardView(
                                        meetup: meetup,
                                        currentUserId: authViewModel.user?.id ?? "",
                                        onJoin: {
                                            Task { await viewModel.joinMeetup(token: authViewModel.getToken(), meetupId: meetup.id) }
                                        },
                                        onLeave: {
                                            Task { await viewModel.leaveMeetup(token: authViewModel.getToken(), meetupId: meetup.id) }
                                        },
                                        onCancel: {
                                            Task { await viewModel.cancelMeetup(token: authViewModel.getToken(), meetupId: meetup.id) }
                                        }
                                    )
                                    .onTapGesture { selectedMeetup = meetup }
                                }
                            }
                            .padding()
                        }
                    }
                }
                .navigationTitle("Meetups")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showSportPicker = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Sports")
                                    .font(.body)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task { await viewModel.fetchMeetups(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id) }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                        }
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .font(.title3)
                        }
                    }
                }
                .task {
                    await viewModel.fetchMeetups(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshMeetups"))) { _ in
                    Task { await viewModel.fetchMeetups(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id) }
                }
                .refreshable {
                    await viewModel.fetchMeetups(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id)
                }
                .sheet(isPresented: $showCreateSheet) {
                    CreateMeetupView(viewModel: viewModel)
                        .environmentObject(authViewModel)
                }
                .sheet(item: $selectedMeetup) { meetup in
                    NavigationView {
                        MeetupDetailView(viewModel: viewModel, meetup: meetup)
                            .environmentObject(authViewModel)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func todayDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func isStartingSoon(_ meetup: Meetup) -> Bool {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        guard let date = df.date(from: "\(meetup.date) \(meetup.time)") else { return false }
        let hoursUntil = date.timeIntervalSinceNow / 3600
        return hoursUntil >= 0 && hoursUntil <= 3
    }

    private func quickFilterIcon(_ filter: MeetupQuickFilter) -> String {
        switch filter {
        case .today: return "calendar.badge.clock"
        case .beginnerFriendly: return "figure.walk"
        case .startingSoon: return "bolt.fill"
        }
    }
}
