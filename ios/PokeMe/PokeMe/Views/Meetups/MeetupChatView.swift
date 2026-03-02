import SwiftUI

struct MeetupChatView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = MeetupChatViewModel()
    @Environment(\.dismiss) var dismiss

    let meetupId: String
    let meetupTitle: String

    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MeetupMessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.senderId == (authViewModel.user?.id ?? "")
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let last = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = viewModel.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 12) {
                    TextField("Message...", text: $messageText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isInputFocused)

                    Button(action: sendMessage) {
                        if viewModel.isSending {
                            ProgressView()
                                .tint(.orange)
                                .frame(width: 36, height: 36)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(
                                        messageText.isEmpty
                                            ? LinearGradient(colors: [Color(.systemGray4), Color(.systemGray4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 36, height: 36)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(messageText.isEmpty || viewModel.isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle(meetupTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                            Text("Close")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    }
                }
            }
            .onAppear {
                viewModel.configure(
                    meetupId: meetupId,
                    currentUserId: authViewModel.user?.id ?? ""
                )
                Task {
                    await viewModel.fetchMessages(token: authViewModel.getToken())
                }
                viewModel.startPolling(token: authViewModel.getToken())
            }
            .onDisappear {
                viewModel.stopPolling()
            }
        }
    }

    private func sendMessage() {
        let text = messageText
        messageText = ""
        Task {
            await viewModel.sendMessage(token: authViewModel.getToken(), text: text)
        }
    }
}

struct MeetupMessageBubble: View {
    let message: MeetupMessage
    let isFromCurrentUser: Bool

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top) {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 3) {
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }

                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isFromCurrentUser
                            ? LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(18)

                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.timeStyle = .short
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.timeStyle = .short
            return display.string(from: date)
        }
        return ""
    }
}
