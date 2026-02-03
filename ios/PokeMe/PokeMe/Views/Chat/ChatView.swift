import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.dismiss) var dismiss

    let partnerName: String

    @State private var messageText = ""
    @State private var selectedMessageForReaction: Message?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    currentUserId: authViewModel.user?.id ?? "",
                                    onReactionTap: {
                                        selectedMessageForReaction = message
                                    }
                                )
                                .id(message.id)
                            }

                            // Typing indicator
                            if viewModel.partnerIsTyping {
                                TypingIndicatorView()
                                    .id("typing-indicator")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.partnerIsTyping) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 12) {
                    TextField("Message...", text: $messageText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isInputFocused)
                        .onChange(of: messageText) { newValue in
                            if !newValue.isEmpty {
                                viewModel.userIsTyping(token: authViewModel.getToken())
                            }
                        }

                    Button(action: sendMessage) {
                        if viewModel.isSending {
                            ProgressView()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(messageText.isEmpty ? .gray : .blue)
                        }
                    }
                    .disabled(messageText.isEmpty || viewModel.isSending)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle(partnerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.setCurrentUser(id: authViewModel.user?.id ?? "")
                Task {
                    await viewModel.fetchMessages(token: authViewModel.getToken())
                }
                viewModel.startPolling(token: authViewModel.getToken())
            }
            .onDisappear {
                viewModel.stopPolling()
                Task {
                    await viewModel.stopTyping(token: authViewModel.getToken())
                }
            }
            .sheet(item: $selectedMessageForReaction) { message in
                ReactionPickerSheet(
                    message: message,
                    currentUserId: authViewModel.user?.id ?? "",
                    onSelectReaction: { emoji in
                        let messageId = message.id
                        selectedMessageForReaction = nil
                        Task {
                            await viewModel.toggleReaction(
                                token: authViewModel.getToken(),
                                messageId: messageId,
                                emoji: emoji
                            )
                        }
                    },
                    onDismiss: {
                        selectedMessageForReaction = nil
                    }
                )
                .presentationDetents([.height(140)])
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if viewModel.partnerIsTyping {
            withAnimation {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            }
        } else if let lastMessage = viewModel.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        Task {
            let text = messageText
            messageText = ""
            let _ = await viewModel.sendMessage(token: authViewModel.getToken(), text: text)
        }
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var dotScales: [CGFloat] = [1, 1, 1]
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    @State private var currentDot = 0

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(.systemGray))
                        .frame(width: 10, height: 10)
                        .scaleEffect(dotScales[index])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray5))
            .cornerRadius(20)

            Spacer()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                // Reset previous dot
                dotScales[(currentDot + 2) % 3] = 1.0
                // Animate current dot
                dotScales[currentDot] = 1.4
                currentDot = (currentDot + 1) % 3
            }
        }
    }
}

// MARK: - Reaction Picker Sheet

struct ReactionPickerSheet: View {
    let message: Message
    let currentUserId: String
    let onSelectReaction: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("React to message")
                .font(.headline)
                .padding(.top)

            HStack(spacing: 16) {
                ForEach(ChatViewModel.allowedReactions, id: \.self) { emoji in
                    Button(action: {
                        onSelectReaction(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 36))
                            .padding(8)
                            .background(
                                hasUserReacted(with: emoji)
                                    ? Color.blue.opacity(0.3)
                                    : Color(.systemGray6)
                            )
                            .cornerRadius(12)
                    }
                }
            }

            Button("Cancel") {
                onDismiss()
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
        }
        .padding()
    }

    private func hasUserReacted(with emoji: String) -> Bool {
        guard let reactions = message.reactions else { return false }
        return reactions.contains { $0.userId == currentUserId && $0.emoji == emoji }
    }
}

// MARK: - Reaction Bubble (iMessage style)

struct ReactionBubble: View {
    let reactions: [Reaction]
    let isFromCurrentUser: Bool

    var body: some View {
        let grouped = groupReactions()

        if !grouped.isEmpty {
            HStack(spacing: 2) {
                ForEach(grouped, id: \.emoji) { item in
                    HStack(spacing: 1) {
                        Text(item.emoji)
                            .font(.system(size: 14))
                        if item.count > 1 {
                            Text("\(item.count)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
    }

    private func groupReactions() -> [(emoji: String, count: Int)] {
        var counts: [String: Int] = [:]
        for reaction in reactions {
            counts[reaction.emoji, default: 0] += 1
        }
        return counts.map { (emoji: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let currentUserId: String
    var onReactionTap: (() -> Void)?

    private var hasReactions: Bool {
        guard let reactions = message.reactions else { return false }
        return !reactions.isEmpty
    }

    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 0) {
                // Message bubble with reaction overlay
                ZStack(alignment: message.isFromCurrentUser ? .bottomLeading : .bottomTrailing) {
                    Text(message.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isFromCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                        .cornerRadius(18)
                        .onTapGesture(count: 2) {
                            // Double tap to quick-react with thumbs up
                            onReactionTap?()
                        }
                        .onLongPressGesture {
                            onReactionTap?()
                        }

                    // Reaction bubble overlay (iMessage style - on corner)
                    if hasReactions {
                        ReactionBubble(
                            reactions: message.reactions ?? [],
                            isFromCurrentUser: message.isFromCurrentUser
                        )
                        .offset(
                            x: message.isFromCurrentUser ? -8 : 8,
                            y: 12
                        )
                    }
                }
                .padding(.bottom, hasReactions ? 14 : 0)

                // Time and read receipt
                HStack(spacing: 4) {
                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Read receipt for sent messages (iMessage style)
                    if message.isFromCurrentUser {
                        if message.isReadByPartner(currentUserId: currentUserId) {
                            Text("Read")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue)
                        } else {
                            Text("Delivered")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.top, 2)
            }

            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return ""
    }
}

#Preview {
    ChatView(partnerName: "Jane Doe")
        .environmentObject(AuthViewModel())
}
