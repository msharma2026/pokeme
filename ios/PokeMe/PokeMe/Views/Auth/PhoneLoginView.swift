import SwiftUI

struct PhoneLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showVerification = false
    @State private var normalizedPhone = ""

    var body: some View {
        VStack(spacing: 24) {
            // Logo/Title
            VStack(spacing: 8) {
                Text("PokeMe")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)

                Text("Enter your phone number")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)

            Spacer()

            // Phone Input
            VStack(spacing: 16) {
                HStack {
                    Text("+1")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)

                    TextField("(530) 555-0000", text: $phoneNumber)
                        .font(.title2)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                Text("For testing, use: 530-555-0000")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: sendCode) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Code")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(phoneNumber.count >= 10 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isLoading || phoneNumber.count < 10)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Email login option
            Button(action: { authViewModel.showEmailLogin = true }) {
                HStack {
                    Text("Prefer email?")
                        .foregroundColor(.secondary)
                    Text("Login with email")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showVerification) {
            VerifyCodeView(phone: normalizedPhone)
                .environmentObject(authViewModel)
        }
    }

    private func sendCode() {
        isLoading = true
        errorMessage = nil

        // Normalize phone number
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
