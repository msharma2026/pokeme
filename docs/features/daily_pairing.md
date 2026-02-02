# Daily Pairing Feature

## Overview

The Daily Pairing feature is the core functionality of PokeMe. Each day, users are automatically paired with a random student from their campus. This encourages organic social connections and helps students meet new people outside their usual social circles.

## Feature Requirements

### Functional Requirements

1. **One Match Per Day**: Each user receives exactly one match per day
2. **Random Pairing**: Matches are made randomly from available users
3. **Optional Filters**: Users can optionally filter by preferences (e.g., same major)
4. **Disconnect Penalty**: If a user disconnects, they cannot get a new match until the next day
5. **Match Persistence**: Once matched, the pairing persists for the entire day

### Non-Functional Requirements

1. **Reset Time**: Matches reset at midnight Pacific Time
2. **Fairness**: All waiting users have equal chance of being matched
3. **Privacy**: Only display name and major are shared initially

## User Stories

### US-1: Get Today's Match
**As a** registered user
**I want to** see my daily match
**So that** I can connect with a new person

**Acceptance Criteria:**
- User can view their current match after logging in
- Match displays partner's name and major
- If no match exists, user is added to the matching pool
- If user disconnected today, they see a "wait until tomorrow" message

### US-2: Disconnect from Match
**As a** matched user
**I want to** disconnect from my current match
**So that** I can opt out if the connection isn't working

**Acceptance Criteria:**
- User can click "Disconnect" button
- After disconnecting, user cannot get a new match today
- Partner is notified that the match was disconnected
- User sees when their next match will be available

### US-3: Filter by Major
**As a** user
**I want to** prefer matches from my major
**So that** I can meet people with similar academic interests

**Acceptance Criteria:**
- User can enable "Prefer same major" in settings
- When enabled, matching algorithm prioritizes same-major users
- If no same-major users available, falls back to any available user

## Technical Design

### Matching Algorithm

```
findOrCreateMatch(userId):
    today = getCurrentDate()  // "YYYY-MM-DD" in Pacific Time

    // Step 1: Check for existing match
    existingMatch = query matches where date = today AND (user1Id = userId OR user2Id = userId)
    if existingMatch:
        if existingMatch.status == "disconnected":
            return { status: "disconnected", nextMatchAt: tomorrow }
        else:
            return { status: "matched", match: existingMatch }

    // Step 2: Find partner in pool
    pool = query matchPool/{today}/users
    candidates = pool.filter(id != userId)

    if user.filters.preferSameMajor AND user.major:
        sameMajorCandidates = candidates.filter(major == user.major)
        if sameMajorCandidates.length > 0:
            candidates = sameMajorCandidates

    if candidates.length > 0:
        partner = random(candidates)
        match = createMatch(userId, partner.id, today)
        removeFromPool(userId, today)
        removeFromPool(partner.id, today)
        return { status: "matched", match: match }

    // Step 3: Add to pool and wait
    addToPool(userId, today)
    return { status: "waiting" }
```

### Data Flow

```
User opens app
      │
      ▼
GET /api/match/today
      │
      ▼
┌─────────────────────────┐
│   Check existing match  │
└───────────┬─────────────┘
            │
    ┌───────┴───────┐
    ▼               ▼
Match exists    No match
    │               │
    │               ▼
    │       ┌───────────────┐
    │       │ Find partner  │
    │       │   in pool     │
    │       └───────┬───────┘
    │               │
    │       ┌───────┴───────┐
    │       ▼               ▼
    │   Partner found   No partner
    │       │               │
    │       ▼               ▼
    │   Create match    Add to pool
    │       │               │
    │       ▼               ▼
    └──►Return match   Return "waiting"
```

### Database Operations

#### Creating a Match
```javascript
// matches/{matchId}
{
    id: "match123",
    date: "2026-02-01",
    user1Id: "userA",
    user2Id: "userB",
    status: "active",
    disconnectedBy: null,
    createdAt: "2026-02-01T08:00:00Z",
    updatedAt: "2026-02-01T08:00:00Z"
}
```

#### Adding to Pool
```javascript
// matchPool/2026-02-01/users/{userId}
{
    major: "Computer Science",
    filters: { preferSameMajor: true },
    addedAt: "2026-02-01T09:00:00Z"
}
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| /api/match/today | GET | Get or create today's match |
| /api/match/disconnect | POST | Disconnect from current match |

See [API.md](../API.md) for detailed request/response formats.

## UI Components

### HomeView States

1. **Loading**: Spinner with "Finding your match..."
2. **Matched**: MatchCardView with partner info and Disconnect button
3. **Waiting**: Hourglass icon with "You're in the pool!" message
4. **Disconnected**: Moon icon with "See you tomorrow!" message
5. **Error**: Warning icon with error message and retry button

### MatchCardView
- Circle avatar with first letter of name
- Partner's display name
- Partner's major (if available)
- "Connected" status badge

## Test Cases

### Unit Tests

1. **TC-1**: User with no match today gets added to pool
2. **TC-2**: User with existing match gets same match on repeat request
3. **TC-3**: Two users in pool get matched together
4. **TC-4**: Disconnected user cannot get new match same day
5. **TC-5**: Major filter prioritizes same-major users
6. **TC-6**: Match resets at midnight

### Integration Tests

1. **TC-7**: Full flow: Register → Login → Get Match → Disconnect
2. **TC-8**: Two users register and get matched with each other
3. **TC-9**: Token expiration handled gracefully

## Future Enhancements

1. Push notifications when matched
2. Match history view
3. More filter options (year, interests)
4. Block/report functionality
5. Match quality feedback
