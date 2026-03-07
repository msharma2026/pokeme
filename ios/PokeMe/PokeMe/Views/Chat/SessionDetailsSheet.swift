import SwiftUI

struct SessionDetailsSheet: View {
    let session: Session
    let currentUserId: String
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onProposeChange: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showCancelConfirmation = false

    private var isResponder: Bool { session.responderId == currentUserId }
    private var isPending: Bool { session.status == "pending" }
    private var isAccepted: Bool { session.status == "accepted" }
    private var isChangeProposal: Bool { session.isChangeProposal == true }

    var body: some View {
        NavigationView {
            List {
                statusSection
                detailsSection
                actionsSection
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isPending
                         ? (isChangeProposal ? "Changes Proposed" : "Awaiting Response")
                         : "Session Confirmed")
                        .font(.headline)
                    Text(isPending
                         ? (isChangeProposal
                            ? "New session details have been proposed. Review and respond."
                            : "Waiting for the other person to respond.")
                         : "This session has been accepted by both parties.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isPending
                      ? (isChangeProposal ? "arrow.triangle.2.circlepath.circle.fill" : "clock.fill")
                      : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(isPending ? (isChangeProposal ? .purple : .orange) : .green)
            }
            .padding(.vertical, 4)
        }
    }

    private var detailsSection: some View {
        let dateStr = AvailabilityHelper.formatSessionDateLong(session.date, fallback: session.day)
        let timeStr = "\(AvailabilityHelper.formatHour(session.startHour)) – \(AvailabilityHelper.formatHour(session.endHour))"
        return Section("Details") {
            detailRow(icon: "sportscourt", label: "Sport", value: session.sport)
            detailRow(icon: "calendar", label: "Date", value: dateStr)
            detailRow(icon: "clock", label: "Time", value: timeStr)
            if let loc = session.location, !loc.isEmpty {
                detailRow(icon: "mappin", label: "Location", value: loc)
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if isPending && isResponder {
            Section("Respond") {
                Button {
                    onAccept()
                    dismiss()
                } label: {
                    Label("Accept Session", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Button {
                    onDecline()
                    dismiss()
                } label: {
                    Label("Decline Session", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }

        Section("Actions") {
            Button {
                onProposeChange()
                dismiss()
            } label: {
                Label("Propose Change", systemImage: "pencil.circle")
                    .foregroundColor(.orange)
            }

            Button(role: .destructive) {
                showCancelConfirmation = true
            } label: {
                Label("Cancel Session", systemImage: "trash")
            }
        }
        .alert("Cancel Session?", isPresented: $showCancelConfirmation) {
            Button("Yes, Cancel", role: .destructive) {
                onCancel()
                dismiss()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this session? The other person will be notified.")
        }
    }

    // MARK: - Helpers

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
