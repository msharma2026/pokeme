import SwiftUI

struct MeetupsListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MeetupViewModel()
    @State private var showCreateSheet = false
    @State private var selectedMeetup: Meetup?
    @State private var showSportPicker = true

    private let sports = ["All"] + Sport.allCases.map { $0.rawValue }
    @State private var selectedSport = "All"

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
                                            : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundColor(selectedSport == sport ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Meetups list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading meetups...")
                    Spacer()
                } else if viewModel.meetups.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No meetups yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Create one to get started!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.meetups) { meetup in
                                MeetupCardView(
                                    meetup: meetup,
                                    currentUserId: authViewModel.user?.id ?? "",
                                    onJoin: {
                                        Task {
                                            await viewModel.joinMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                        }
                                    },
                                    onLeave: {
                                        Task {
                                            await viewModel.leaveMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                        }
                                    },
                                    onCancel: {
                                        Task {
                                            await viewModel.cancelMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                        }
                                    }
                                )
                                .onTapGesture {
                                    selectedMeetup = meetup
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Meetups")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSportPicker = true }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
            .onAppear {
                viewModel.startPolling(token: authViewModel.getToken(), currentUserId: authViewModel.user?.id)
            }
            .onDisappear {
                viewModel.stopPolling()
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
        } // end else
    }
}
