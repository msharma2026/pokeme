import SwiftUI

struct MeetupDetailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: MeetupViewModel
    let meetup: Meetup
    @Environment(\.dismiss) var dismiss

    private var currentUserId: String { authViewModel.user?.id ?? "" }
    private var isHost: Bool { meetup.hostId == currentUserId }
    private var isJoined: Bool { meetup.participants?.contains(currentUserId) ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(meetup.sport)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)

                    Text(meetup.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Hosted by \(meetup.hostName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    if let desc = meetup.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                    }

                    Label(meetup.date, systemImage: "calendar")
                    Label(meetup.time, systemImage: "clock")

                    if let location = meetup.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                }

                // Skill levels
                if let levels = meetup.skillLevels, !levels.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Skill Levels")
                            .font(.headline)
                        HStack(spacing: 6) {
                            ForEach(levels, id: \.self) { level in
                                Text(level)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                // Participants
                VStack(alignment: .leading, spacing: 6) {
                    Text("Players (\(meetup.participantCount)/\(meetup.playerLimit ?? 10))")
                        .font(.headline)

                    ProgressView(value: Double(meetup.participantCount), total: Double(meetup.playerLimit ?? 10))
                        .tint(.orange)
                }

                Divider()

                // Action
                HStack {
                    Spacer()
                    if isHost {
                        Button(action: {
                            Task {
                                await viewModel.cancelMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                dismiss()
                            }
                        }) {
                            Text("Cancel Meetup")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(20)
                        }
                    } else if isJoined {
                        Button(action: {
                            Task {
                                await viewModel.leaveMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                dismiss()
                            }
                        }) {
                            Text("Leave Meetup")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .cornerRadius(20)
                        }
                    } else if !meetup.isFull {
                        Button(action: {
                            Task {
                                await viewModel.joinMeetup(token: authViewModel.getToken(), meetupId: meetup.id)
                                dismiss()
                            }
                        }) {
                            Text("Join Meetup")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(20)
                        }
                    } else {
                        Text("This meetup is full")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .navigationTitle("Meetup Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
