import SwiftUI

struct MatchCardView: View {
    let match: Match
    let onPoke: () -> Void
    let onChat: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Avatar placeholder
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 100, height: 100)
                .overlay(
                    Text(match.partnerName.prefix(1).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                )

            // Name
            Text(match.partnerName)
                .font(.title)
                .fontWeight(.bold)

            // Major
            if let major = match.partnerMajor {
                HStack {
                    Image(systemName: "book.closed")
                    Text(major)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            // Poke counts
            HStack(spacing: 24) {
                VStack {
                    Text("\(match.myPokes)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("You poked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(match.partnerPokes)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("They poked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)

            // Action buttons
            HStack(spacing: 12) {
                // Chat button
                Button(action: onChat) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Chat")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }

                // Poke button
                Button(action: onPoke) {
                    HStack {
                        Image(systemName: "hand.point.right.fill")
                        Text("Poke!")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            // Status badge
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .cornerRadius(20)
        }
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

#Preview {
    MatchCardView(
        match: Match(
            id: "1",
            date: "2026-02-01",
            partnerId: "123",
            partnerName: "Jane Doe",
            partnerMajor: "Computer Science",
            status: "active",
            myPokes: 3,
            partnerPokes: 5,
            createdAt: "2026-02-01T12:00:00Z"
        ),
        onPoke: {},
        onChat: {}
    )
}
