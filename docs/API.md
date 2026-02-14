# PokeMe API Documentation

## Base URL

```
http://localhost:3000/api
```

## Authentication

Protected endpoints require a JWT token in the Authorization header:

```
Authorization: Bearer <token>
```

## Endpoints

---

### POST /auth/register

Create a new user account.

**Request Body:**
```json
{
    "email": "student@ucdavis.edu",
    "password": "securePassword123",
    "displayName": "John Doe",
    "major": "Computer Science"  // optional
}
```

**Response (201 Created):**
```json
{
    "success": true,
    "data": {
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        "user": {
            "id": "abc123",
            "email": "student@ucdavis.edu",
            "displayName": "John Doe",
            "major": "Computer Science",
            "socialPoints": 100,
            "createdAt": "2026-02-01T00:00:00.000Z"
        }
    }
}
```

**Errors:**
- `400 VALIDATION_ERROR` - Missing required fields
- `409 USER_EXISTS` - Email already registered

---

### POST /auth/login

Authenticate an existing user.

**Request Body:**
```json
{
    "email": "student@ucdavis.edu",
    "password": "securePassword123"
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        "user": {
            "id": "abc123",
            "email": "student@ucdavis.edu",
            "displayName": "John Doe",
            "major": "Computer Science",
            "socialPoints": 150
        }
    }
}
```

**Errors:**
- `400 VALIDATION_ERROR` - Missing email or password
- `401 INVALID_CREDENTIALS` - Wrong email or password

---

### GET /auth/me

Get the current authenticated user.

**Headers:**
```
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "id": "abc123",
        "email": "student@ucdavis.edu",
        "displayName": "John Doe",
        "major": "Computer Science",
        "socialPoints": 150,
        "createdAt": "2026-02-01T00:00:00.000Z"
    }
}
```

**Errors:**
- `401 UNAUTHORIZED` - No token provided
- `401 INVALID_TOKEN` - Token expired or invalid
- `404 USER_NOT_FOUND` - User no longer exists

---

### GET /match/today

Get or create today's match for the authenticated user.

**Headers:**
```
Authorization: Bearer <token>
```

**Response - Match Found (200 OK):**
```json
{
    "success": true,
    "data": {
        "match": {
            "id": "match123",
            "date": "2026-02-01",
            "partnerId": "xyz789",
            "partnerName": "Jane Smith",
            "partnerMajor": "Biology",
            "status": "active",
            "createdAt": "2026-02-01T08:00:00.000Z"
        },
        "status": "matched"
    }
}
```

**Response - Waiting in Pool (200 OK):**
```json
{
    "success": true,
    "data": {
        "match": null,
        "status": "waiting",
        "message": "You're in the matching pool. Check back soon!"
    }
}
```

**Response - Disconnected Today (200 OK):**
```json
{
    "success": true,
    "data": {
        "match": null,
        "status": "disconnected",
        "message": "You disconnected today. New match available tomorrow.",
        "nextMatchAt": "2026-02-02T00:00:00.000Z"
    }
}
```

**Errors:**
- `401 UNAUTHORIZED` - Not authenticated

---

### POST /match/disconnect

Disconnect from the current match. User must wait until tomorrow for a new match.

**Headers:**
```
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "message": "Match disconnected. New match available tomorrow.",
        "nextMatchAt": "2026-02-02T00:00:00.000Z"
    }
}
```

**Errors:**
- `400 DISCONNECT_FAILED` - No active match found or already disconnected
- `401 UNAUTHORIZED` - Not authenticated

---

### GET /match/messages

Get all messages for the current match.

**Headers:**
```
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "messages": [
            {
                "id": "msg123",
                "matchId": "match456",
                "senderId": "user789",
                "text": "Hello!",
                "createdAt": "2026-02-01T10:00:00.000Z",
                "readBy": ["user789", "user012"],
                "reactions": [
                    {
                        "emoji": "👍",
                        "userId": "user012",
                        "createdAt": "2026-02-01T10:01:00.000Z"
                    }
                ]
            }
        ],
        "matchId": "match456",
        "partnerIsTyping": false
    }
}
```

**Errors:**
- `400 NO_MATCH` - No active match found for today
- `401 UNAUTHORIZED` - Not authenticated

---

### POST /match/messages

Send a message to your current match.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
    "text": "Hello, nice to meet you!"
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "message": {
            "id": "msg123",
            "matchId": "match456",
            "senderId": "user789",
            "text": "Hello, nice to meet you!",
            "createdAt": "2026-02-01T10:00:00.000Z",
            "readBy": ["user789"],
            "reactions": []
        }
    }
}
```

**Errors:**
- `400 NO_MATCH` - No active match found for today
- `400 MATCH_INACTIVE` - Cannot send messages to a disconnected match
- `400 VALIDATION_ERROR` - Message text is required or too long (max 1000 characters)
- `401 UNAUTHORIZED` - Not authenticated

---

### POST /match/messages/:messageId/reactions

Add a reaction to a message.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
    "emoji": "👍"
}
```

**Allowed Reactions:** 👍, ❤️, 😂, 😮, 😢

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "reaction": {
            "messageId": "msg123",
            "userId": "user789",
            "emoji": "👍",
            "createdAt": "2026-02-01T10:01:00.000Z"
        }
    }
}
```

**Errors:**
- `400 NO_MATCH` - No active match found for today
- `400 VALIDATION_ERROR` - Invalid reaction emoji
- `404 MESSAGE_NOT_FOUND` - Message not found
- `401 UNAUTHORIZED` - Not authenticated

---

### DELETE /match/messages/:messageId/reactions/:emoji

Remove a reaction from a message. Users can only remove their own reactions.

**Headers:**
```
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "message": "Reaction removed"
    }
}
```

**Errors:**
- `400 NO_MATCH` - No active match found for today
- `404 MESSAGE_NOT_FOUND` - Message not found
- `401 UNAUTHORIZED` - Not authenticated

---

### POST /match/messages/read

Mark messages as read by the current user.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
    "messageIds": ["msg123", "msg456"]
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "updatedCount": 2
    }
}
```

**Errors:**
- `400 NO_MATCH` - No active match found for today
- `400 VALIDATION_ERROR` - messageIds is required
- `401 UNAUTHORIZED` - Not authenticated

---

### POST /match/typing

Update the current user's typing status.

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
    "isTyping": true
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "isTyping": true
    }
}
```

**Errors:**
- `400 NO_MATCH` - No active match found for today
- `400 MATCH_INACTIVE` - Cannot update typing status for inactive match
- `401 UNAUTHORIZED` - Not authenticated

---

### GET /match/typing

Get the partner's typing status. Typing indicators expire after 5 seconds.

**Headers:**
```
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "partnerIsTyping": true
    }
}
```

**Errors:**
- `400 NO_MATCH` - No active match found for today
- `401 UNAUTHORIZED` - Not authenticated

---

### GET /matches/:matchId/compatible-times

Compute overlap of both users' expanded availability and shared sports.

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "compatibleTimes": {
            "Monday": ["9:00", "10:00", "14:00", "15:00"],
            "Wednesday": ["17:00", "18:00"]
        },
        "sharedSports": [
            {
                "sport": "Tennis",
                "userLevel": "Intermediate",
                "partnerLevel": "Beginner"
            }
        ]
    }
}
```

---

### POST /matches/:matchId/sessions

Create a session proposal. Auto-creates a system message in chat.

**Request Body:**
```json
{
    "sport": "Tennis",
    "day": "Monday",
    "startHour": 14,
    "endHour": 16,
    "location": "ARC Tennis Courts"
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "session": {
            "id": "session-uuid",
            "matchId": "match-uuid",
            "proposerId": "user1",
            "responderId": "user2",
            "sport": "Tennis",
            "day": "Monday",
            "startHour": 14,
            "endHour": 16,
            "location": "ARC Tennis Courts",
            "status": "pending",
            "createdAt": "2026-02-13T10:00:00.000Z"
        }
    }
}
```

---

### PUT /matches/:matchId/sessions/:sessionId

Accept or decline a session (responder only).

**Request Body:**
```json
{
    "action": "accept"
}
```

---

### GET /matches/:matchId/sessions

List all sessions for a match.

---

### GET /sessions/upcoming

Get all accepted future sessions for the current user.

---

### POST /meetups

Create a new public meetup.

**Request Body:**
```json
{
    "sport": "Basketball",
    "title": "Pickup Basketball",
    "description": "Casual game at the ARC",
    "date": "2026-02-15",
    "time": "14:00",
    "location": "ARC Gym",
    "skillLevels": ["Beginner", "Intermediate"],
    "playerLimit": 10
}
```

**Response (201 Created):**
```json
{
    "success": true,
    "data": {
        "meetup": {
            "id": "meetup-uuid",
            "hostId": "user1",
            "hostName": "John Doe",
            "sport": "Basketball",
            "title": "Pickup Basketball",
            "date": "2026-02-15",
            "time": "14:00",
            "location": "ARC Gym",
            "skillLevels": ["Beginner", "Intermediate"],
            "playerLimit": 10,
            "participants": ["user1"],
            "status": "active",
            "createdAt": "2026-02-13T10:00:00.000Z"
        }
    }
}
```

---

### GET /meetups

List active meetups. Optional query params: `?sport=Basketball&date=2026-02-15`

---

### GET /meetups/mine

Get meetups the current user has hosted or joined.

---

### POST /meetups/:meetupId/join

Join a meetup. Fails if full or already joined.

---

### POST /meetups/:meetupId/leave

Leave a meetup. Host cannot leave (must cancel instead).

---

### DELETE /meetups/:meetupId

Cancel a meetup (host only).

---

### GET /health

Health check endpoint.

**Response (200 OK):**
```json
{
    "success": true,
    "data": {
        "status": "ok",
        "timestamp": "2026-02-01T12:00:00.000Z"
    }
}
```

---

## Error Response Format

All errors follow this format:

```json
{
    "success": false,
    "error": {
        "code": "ERROR_CODE",
        "message": "Human readable description"
    }
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| VALIDATION_ERROR | 400 | Missing or invalid request data |
| UNAUTHORIZED | 401 | No authentication token provided |
| INVALID_TOKEN | 401 | Token is expired or invalid |
| INVALID_CREDENTIALS | 401 | Wrong email or password |
| USER_NOT_FOUND | 404 | User does not exist |
| USER_EXISTS | 409 | Email already registered |
| DISCONNECT_FAILED | 400 | Cannot disconnect (no match or already disconnected) |
| INTERNAL_ERROR | 500 | Server error |

---

## Testing with cURL

### Register
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"password123","displayName":"Test User"}'
```

### Login
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"password123"}'
```

### Get Today's Match
```bash
curl http://localhost:3000/api/match/today \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### Disconnect
```bash
curl -X POST http://localhost:3000/api/match/disconnect \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```
