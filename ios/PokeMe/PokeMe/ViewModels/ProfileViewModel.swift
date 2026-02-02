import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func updateProfile(
        token: String?,
        displayName: String,
        major: String?,
        bio: String?,
        socials: Socials?
    ) async -> User? {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return nil
        }

        isLoading = true
        errorMessage = nil

        do {
            let update = ProfileUpdateRequest(
                displayName: displayName,
                major: major,
                bio: bio,
                socials: socials
            )
            let user = try await ProfileService.shared.updateProfile(token: token, update: update)
            successMessage = "Profile updated!"
            isLoading = false
            return user
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            isLoading = false
            return nil
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    func uploadProfilePicture(token: String?, imageData: Data) async -> User? {
        guard let token = token else {
            errorMessage = "Not authenticated"
            return nil
        }

        isLoading = true
        errorMessage = nil

        let base64String = "data:image/jpeg;base64," + imageData.base64EncodedString()

        do {
            let user = try await ProfileService.shared.uploadProfilePicture(token: token, imageBase64: base64String)
            successMessage = "Profile picture updated!"
            isLoading = false
            return user
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            isLoading = false
            return nil
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
