import SwiftUI

struct SessionPinnedCard: View {
    let session: Session
    let currentUserId: String
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onViewDetails: () -> Void
    let onProposeChange: () -> Void
    let onCancel: () -> Void

    private var isResponder: Bool { session.responderId == currentUserId }
    private var isPending: Bool { session.status == "pending" }
    private var isAccepted: Bool { session.status == "accepted" }
    private var isChangeProposal: Bool { session.isChangeProposal == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            detailsRow
            actionRow
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.5), .pink.opacity(0.5)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.orange)
                .font(.subheadline)
            Text(isPending ? (isChangeProposal ? "Changes Proposed" : "Session Proposed") : "Upcoming Session")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            Spacer()
            statusBadge
        }
    }

    private var detailsRow: some View {
        let dateStr = AvailabilityHelper.formatSessionDateLong(session.date, fallback: session.day)
        let timeStr = "\(AvailabilityHelper.formatHour(session.startHour)) – \(AvailabilityHelper.formatHour(session.endHour))"
        return VStack(alignment: .leading, spacing: 4) {
            Label(session.sport, systemImage: "sportscourt")
                .font(.subheadline)
                .fontWeight(.medium)
            Label("\(dateStr) · \(timeStr)", systemImage: "clock")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let loc = session.location, !loc.isEmpty {
                Label(loc, systemImage: "mappin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            if isPending && isResponder {
                pinnedButton("Accept", colors: [.green, .mint], action: onAccept)
                pinnedButton("Decline", colors: [Color(.systemGray3), Color(.systemGray4)], action: onDecline)
            } else if isPending {
                Text("Awaiting response…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isAccepted {
                pinnedButton("Propose Change", colors: [.orange, .pink], action: onProposeChange)
                pinnedButton("Cancel", colors: [Color(.systemGray3), Color(.systemGray4)], action: onCancel)
            }

            Spacer()

            Button("Details", action: onViewDetails)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isPending {
            Text(isChangeProposal ? "Review Changes" : "Pending")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isChangeProposal ? .purple : .orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((isChangeProposal ? Color.purple : Color.orange).opacity(0.12))
                .cornerRadius(6)
        } else if isAccepted {
            Text("Confirmed ✓")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
        }
    }

    @ViewBuilder
    private func pinnedButton(_ label: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(10)
        }
    }
}
