import SwiftUI

/// Compact centered event pill shown in chat when a session is proposed, accepted, declined, or cancelled.
struct SessionProposalBubble: View {
    let message: Message

    private var eventIcon: String {
        guard message.isSessionResponse, let action = message.metadata?.action else {
            return "calendar.badge.clock"
        }
        switch action {
        case "accept":  return "checkmark.circle.fill"
        case "decline": return "xmark.circle.fill"
        case "cancel":  return "xmark.circle.fill"
        default:        return "calendar.badge.clock"
        }
    }

    private var iconColor: Color {
        guard message.isSessionResponse, let action = message.metadata?.action else {
            return .orange
        }
        switch action {
        case "accept":           return .green
        case "decline", "cancel": return .red
        default:                 return .orange
        }
    }

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: eventIcon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(message.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            Spacer()
        }
    }
}
