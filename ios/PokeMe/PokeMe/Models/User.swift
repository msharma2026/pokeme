import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let phone: String?
    let displayName: String
    let major: String?
    let socialPoints: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case phone
        case displayName
        case major
        case socialPoints
        case createdAt
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}
