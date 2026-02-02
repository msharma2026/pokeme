import Foundation

struct Socials: Codable {
    var instagram: String?
    var twitter: String?
    var snapchat: String?
    var linkedin: String?

    init(instagram: String? = nil, twitter: String? = nil, snapchat: String? = nil, linkedin: String? = nil) {
        self.instagram = instagram
        self.twitter = twitter
        self.snapchat = snapchat
        self.linkedin = linkedin
    }
}

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let phone: String?
    var displayName: String
    var major: String?
    var bio: String?
    var profilePicture: String?
    var socials: Socials?
    let socialPoints: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case displayName
        case major
        case bio
        case profilePicture
        case socials
        case socialPoints
        case createdAt
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct ProfileUpdateRequest: Codable {
    var displayName: String?
    var major: String?
    var bio: String?
    var socials: Socials?
}

struct ProfilePictureRequest: Codable {
    let image: String
}
