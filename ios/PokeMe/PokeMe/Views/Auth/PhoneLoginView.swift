import SwiftUI

struct PhoneLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showVerification = false
    @State private var normalizedPhone = ""
    @State private var animateGradient = false
    @State private var bounceEmoji = false

    private let sportEmojis = ["🏀", "⚽", "🎾", "🏐", "🏸", "🏊", "🚴", "🏓"]

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: animateGradient
                    ? [Color.orange, Color.pink, Color.purple]
                    : [Color.purple, Color.blue, Color.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateGradient)

            VStack(spacing: 24) {
                // Animated sport emojis
                HStack(spacing: 12) {
                    ForEach(Array(sportEmojis.prefix(5).enumerated()), id: \.offset) { index, emoji in
                        Text(emoji)
                            .font(.system(size: 28))
                            .offset(y: bounceEmoji ? -8 : 8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.15),
                                value: bounceEmoji
                            )
                    }
                }
                .padding(.top, 50)

                // Logo/Title
                VStack(spacing: 8) {
                    Text("PokeMe")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("Find your sports partner")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Phone Input Card
                VStack(spacing: 16) {
                    HStack {
                        Text("+1")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.leading, 12)

                        TextField("(530) 555-0000", text: $phoneNumber)
                            .font(.title2)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)

                    Text("For testing, use: 530-555-0000")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Button(action: sendCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack {
                                Text("Send Code")
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right.circle.fill")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        phoneNumber.count >= 10
                            ? LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: phoneNumber.count >= 10 ? .orange.opacity(0.4) : .clear, radius: 12, x: 0, y: 6)
                    .disabled(isLoading || phoneNumber.count < 10)
                    .scaleEffect(phoneNumber.count >= 10 ? 1.0 : 0.97)
                    .animation(.spring(response: 0.3), value: phoneNumber.count >= 10)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Email login option
                Button(action: { authViewModel.showEmailLogin = true }) {
                    HStack {
                        Text("Prefer email?")
                            .foregroundColor(.white.opacity(0.6))
                        Text("Login with email")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            animateGradient = true
            bounceEmoji = true
        }
        .sheet(isPresented: $showVerification) {
            VerifyCodeView(phone: normalizedPhone)
                .environmentObject(authViewModel)
        }
    }

    private func sendCode() {
        isLoading = true
        errorMessage = nil

        let digits = phoneNumber.filter { $0.isNumber }
        normalizedPhone = "+1" + digits

        Task {
            do {
                _ = try await PhoneAuthService.shared.sendCode(phone: normalizedPhone)
                await MainActor.run {
                    isLoading = false
                    showVerification = true
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    PhoneLoginView()
        .environmentObject(AuthViewModel())
}
