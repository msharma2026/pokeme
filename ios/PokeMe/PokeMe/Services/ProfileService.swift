import Foundation

class ProfileService {
    static let shared = ProfileService()

    private init() {}

    func updateProfile(token: String, update: ProfileUpdateRequest) async throws -> User {
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.profile,
            method: .PUT,
            body: update,
            token: token
        )
    }

    func uploadProfilePicture(token: String, imageBase64: String) async throws -> User {
        let request = ProfilePictureRequest(image: imageBase64)
        return try await NetworkService.shared.request(
            endpoint: Constants.Endpoints.profilePicture,
            method: .POST,
            body: request,
            token: token
        )
    }
}
