import SwiftUI

struct VerifyCodeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    let phone: String

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Enter Code")
                        .font(.system(size: 32, weight: .bold))

                    Text("We sent a code to \(phone)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)

                Spacer()

                // Code Input
                VStack(spacing: 16) {
                    TextField("123456", text: $code)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isCodeFocused)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                    if phone == "+15305550000" {
                        Text("Test code: 123456")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button(action: verifyCode) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(code.count == 6 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading || code.count != 6)
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Change phone number")
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 32)
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
