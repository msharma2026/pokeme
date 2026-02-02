import XCTest
@testable import PokeMe

final class PokeMeTests: XCTestCase {

    func testUserDecoding() throws {
        let json = """
        {
            "id": "123",
            "email": "test@test.com",
            "displayName": "Test User",
            "major": "Computer Science",
            "socialPoints": 100,
            "createdAt": "2026-02-01T00:00:00Z"
        }
        """

        let data = json.data(using: .utf8)!
        let user = try JSONDecoder().decode(User.self, from: data)

        XCTAssertEqual(user.id, "123")
        XCTAssertEqual(user.email, "test@test.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.major, "Computer Science")
        XCTAssertEqual(user.socialPoints, 100)
    }

    func testMatchDecoding() throws {
        let json = """
        {
            "id": "match123",
            "date": "2026-02-01",
            "partnerId": "partner456",
            "partnerName": "Jane Doe",
            "partnerMajor": "Biology",
            "status": "active",
            "createdAt": "2026-02-01T08:00:00Z"
        }
        """

        let data = json.data(using: .utf8)!
        let match = try JSONDecoder().decode(Match.self, from: data)

        XCTAssertEqual(match.id, "match123")
        XCTAssertEqual(match.partnerName, "Jane Doe")
        XCTAssertEqual(match.status, "active")
    }

    func testAuthResponseDecoding() throws {
        let json = """
        {
            "token": "jwt.token.here",
            "user": {
                "id": "123",
                "email": "test@test.com",
                "displayName": "Test User",
                "major": null,
                "socialPoints": 100,
                "createdAt": "2026-02-01T00:00:00Z"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(AuthResponse.self, from: data)

        XCTAssertEqual(response.token, "jwt.token.here")
        XCTAssertEqual(response.user.id, "123")
    }
}
