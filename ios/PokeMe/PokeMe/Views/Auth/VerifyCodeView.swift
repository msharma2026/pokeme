import SwiftUI

struct VerifyCodeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    let phone: String

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isCodeFocused: Bool
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.15), Color.orange.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 80, height: 80)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }

                        Text("Enter Code")
                            .font(.system(size: 32, weight: .bold, design: .rounded))

                        Text("We sent a code to \(phone)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    Spacer()

                    // Code Input
                    VStack(spacing: 16) {
                        TextField("123456", text: $code)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($isCodeFocused)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        code.count == 6
                                            ? LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing),
                                        lineWidth: 2
                                    )
                            )
                            .offset(x: shakeOffset)

                        if phone == "+15305550000" {
                            Text("Test code: 123456")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }

                        Button(action: verifyCode) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack {
                                    Text("Verify")
                                        .fontWeight(.bold)
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            code.count == 6
                                ? LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: code.count == 6 ? .orange.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                        .disabled(isLoading || code.count != 6)
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Text("Change phone number")
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isCodeFocused = true
            }
        }
    }

    private func verifyCode() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await PhoneAuthService.shared.verifyCode(phone: phone, code: code)
                await MainActor.run {
                    authViewModel.handlePhoneLogin(token: response.token, user: response.user)
                    dismiss()
                }
            } catch let error as NetworkError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.errorDescription
                    // Shake animation on error
                    withAnimation(.default) {
                        shakeOffset = 10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.default) { shakeOffset = -10 }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.default) { shakeOffset = 0 }
                    }
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
    VerifyCodeView(phone: "+15305550000")
        .environmentObject(AuthViewModel())
}
