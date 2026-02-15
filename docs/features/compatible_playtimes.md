# Compatible Playtimes

## Overview
Enables matched users to propose, negotiate, and accept specific times and locations for playing sports together. Uses expanded availability from both users to compute compatible time windows.

## Data Model

### Session Entity
Represents a play proposal between two matched users:
- `matchId`: Reference to the match
- `proposerId`: User who initiated the proposal
- `sport`: Type of sport for this session
- `proposedDate`: Date of proposed play
- `proposedTime`: Time of proposed play (HH:00 format)
- `status`: "pending", "accepted", or "declined"
- `location`: Proposed meeting location (optional)
- `createdAt`: Timestamp

## API Endpoints

### GET /matches/<id>/compatible-times
Computes overlapping availability between matched users for a specific sport:
- **Request**: Query params for date range (optional)
- **Response**: Array of available time windows with format `[{date, times: []}]`
- **Logic**: Expands both users' availability, finds overlap, filters for shared sports

### POST /matches/<id>/sessions
Creates a new session proposal:
- **Request**: `{sport, proposedDate, proposedTime, location}`
- **Response**: Created session object
- **Side Effect**: Auto-generates system message in match thread: "@user proposed playing [sport] on [date] at [time]"

### PUT /matches/<id>/sessions/<sid>
Accept or decline a session proposal:
- **Request**: `{status: "accepted" | "declined"}`
- **Response**: Updated session object
- **Side Effect**: Auto-generates system message:
  - If accepted: "@user accepted the session proposal"
  - If declined: "@user declined the session proposal"

### GET /matches/<id>/sessions
Lists all sessions (proposals) for a specific match:
- **Response**: Array of session objects with full details

### GET /sessions/upcoming
Lists all accepted sessions for the authenticated user:
- **Query**: Filter by date range (optional)
- **Response**: Array of upcoming accepted sessions with match partner details

## Message Integration

Messages now include optional fields:
- `type`: "text" (default), "session_proposal", or "session_response"
- `metadata`: Object containing:
  - For `session_proposal`: `{sessionId, sport, date, time}`
  - For `session_response`: `{sessionId, status}`

## iOS Implementation

### ProposalSheet
Interface for creating a new session proposal:
- Fetches compatible times from backend
- Date/time pickers constrained to compatible windows
- Location input field
- Submit button creates proposal via POST endpoint

### SessionProposalBubble
Renders proposal messages in chat thread:
- Displays proposed sport, date, time, and location
- Shows proposer's name
- **Accept** button: Calls PUT endpoint with status="accepted"
- **Decline** button: Calls PUT endpoint with status="declined"
- Auto-dismisses buttons once proposal is responded to

## Workflow
1. User opens chat with match, taps "Propose Time"
2. ProposalSheet fetches compatible_times from API
3. User selects date/time/location and submits
4. Backend creates Session, auto-generates system message
5. Partner sees SessionProposalBubble with Accept/Decline options
6. Partner responds, backend auto-generates response message
7. Accepted sessions appear in Upcoming Sessions view
