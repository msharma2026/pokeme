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

struct SportEntry: Codable, Identifiable, Hashable {
    let sport: String
    let skillLevel: String

    var id: String { sport }
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
    var sports: [SportEntry]?
    var collegeYear: String?
    var availability: [String: [String]]?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, email, phone, displayName, major, bio
        case profilePicture, socials, sports, collegeYear, availability, createdAt
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
    var sports: [SportEntry]?
    var collegeYear: String?
    var availability: [String: [String]]?
}

struct ProfilePictureRequest: Codable {
    let image: String
}

enum Sport: String, CaseIterable {
    case basketball = "Basketball"
    case tennis = "Tennis"
    case soccer = "Soccer"
    case volleyball = "Volleyball"
    case badminton = "Badminton"
    case running = "Running"
    case swimming = "Swimming"
    case cycling = "Cycling"
    case tabletennis = "Table Tennis"
    case football = "Football"
    case baseball = "Baseball"
    case golf = "Golf"
    case hiking = "Hiking"
    case yoga = "Yoga"
    case rockclimbing = "Rock Climbing"
}

enum SkillLevel: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum CollegeYear: String, CaseIterable {
    case freshman = "Freshman"
    case sophomore = "Sophomore"
    case junior = "Junior"
    case senior = "Senior"
    case graduate = "Graduate"
}
