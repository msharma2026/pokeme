import Foundation

struct SendCodeResponse: Codable {
    let message: String
    let phone: String
}

struct VerifyCodeResponse: Codable {
    let token: String
    let user: User
    let isNewUser: Bool
}

class PhoneAuthService {
    static let shared = PhoneAuthService()

    private init() {}

    func sendCode(phone: String) async throws -> SendCodeResponse {
        let body: [String: Any] = ["phone": phone]

        return try await NetworkService.shared.request(
            endpoint: "/phone/send-code",
            method: .POST,
            body: body
        )
    }

    func verifyCode(phone: String, code: String) async throws -> VerifyCodeResponse {
        let body: [String: Any] = [
            "phone": phone,
            "code": code
        ]

        return try await NetworkService.shared.request(
            endpoint: "/phone/verify-code",
            method: .POST,
            body: body
        )
    }
}
