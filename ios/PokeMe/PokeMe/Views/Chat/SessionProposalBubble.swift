import SwiftUI

struct SessionProposalBubble: View {
    let message: Message
    let currentUserId: String
    let onAccept: (String) -> Void
    let onDecline: (String) -> Void

    private var meta: MessageMetadata? { message.metadata }

    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.orange)
                    Text(message.isSessionProposal ? "Session Proposal" : "Session Update")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }

                if let meta = meta {
                    // Sport
                    if let sport = meta.sport {
                        HStack(spacing: 4) {
                            Image(systemName: "sportscourt")
                                .font(.caption)
                            Text(sport)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

                    // Day & Time
                    if let day = meta.day, let start = meta.startHour, let end = meta.endHour {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("\(day), \(AvailabilityHelper.formatHour(start)) - \(AvailabilityHelper.formatHour(end))")
                                .font(.subheadline)
                        }
                    }

                    // Location
                    if let location = meta.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption)
                            Text(location)
                                .font(.subheadline)
                        }
                    }

                    // Action buttons for responder on pending proposals
                    if message.isSessionProposal && !message.isFromCurrentUser,
                       let sessionId = meta.sessionId {
                        HStack(spacing: 12) {
                            Button(action: { onAccept(sessionId) }) {
                                Text("Accept")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(16)
                            }

                            Button(action: { onDecline(sessionId) }) {
                                Text("Decline")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray4))
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Show response status
                    if message.isSessionResponse, let action = meta.action {
                        HStack(spacing: 4) {
                            Image(systemName: action == "accept" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(action == "accept" ? .green : .red)
                            Text(action == "accept" ? "Accepted" : "Declined")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(action == "accept" ? .green : .red)
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(colors: [.orange.opacity(0.5), .pink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.5
                            )
                    )
            )

            if !message.isFromCurrentUser {
                Spacer(minLength: 40)
            }
        }
    }
}
