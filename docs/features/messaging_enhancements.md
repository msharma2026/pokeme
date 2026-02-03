# Messaging Enhancements Feature

## Overview

The Messaging Enhancements feature adds three interactive capabilities to the PokeMe chat system:

1. **Message Reactions** - Users can react to messages with emojis
2. **Read Receipts** - Users can see when their messages have been read
3. **Typing Indicators** - Users can see when their partner is typing

These features enhance the real-time communication experience and make conversations feel more engaging and responsive.

## Feature Requirements

### Functional Requirements

1. **Message Reactions**
   - Users can add reactions to any message in the conversation
   - Limited to 5 predefined emojis: 👍, ❤️, 😂, 😮, 😢
   - Users can toggle reactions (add/remove) on their own reactions
   - Multiple users can react to the same message
   - Reactions are displayed grouped by emoji with counts

2. **Read Receipts**
   - Messages show a checkmark indicator for sent messages
   - Gray checkmark = message sent
   - Blue checkmark = message read by partner
   - Messages are automatically marked as read when viewed

3. **Typing Indicators**
   - Shows animated "..." bubble when partner is typing
   - Typing status expires after 5 seconds of inactivity
   - Debounced to avoid excessive API calls (max 1 update per 2 seconds)
   - Auto-stops after 3 seconds of not typing

### Non-Functional Requirements

1. **Performance**: Typing indicators use debouncing to minimize API calls
2. **Reliability**: Read receipts and typing failures are silent (non-blocking)
3. **Real-time**: Updates are fetched via polling every 3 seconds

## User Stories

### US-1: React to Message
**As a** matched user
**I want to** react to my partner's messages with emojis
**So that** I can express my feelings without typing

**Acceptance Criteria:**
- User can long-press any message to open reaction picker
- Reaction picker shows 5 emoji options
- Selecting an emoji adds/toggles the reaction
- All reactions are visible below the message bubble
- Reactions show grouped counts (e.g., "👍 2 ❤️ 1")

### US-2: See Read Status
**As a** matched user
**I want to** know when my partner has read my messages
**So that** I know they've seen what I wrote

**Acceptance Criteria:**
- Sent messages show a checkmark next to the timestamp
- Checkmark is gray when sent but unread
- Checkmark turns blue when partner has read the message
- Read status updates automatically during polling

### US-3: See Typing Status
**As a** matched user
**I want to** see when my partner is typing
**So that** I know a response is coming

**Acceptance Criteria:**
- Animated "..." bubble appears when partner is typing
- Indicator appears at the bottom of the message list
- Indicator disappears when partner stops typing
- Indicator expires after 5 seconds of inactivity

## Technical Design

### Data Flow - Reactions

```
User long-presses message
         │
         ▼
ReactionPickerSheet appears
         │
         ▼
User selects emoji
         │
         ▼
POST /match/messages/{id}/reactions
   { "emoji": "👍" }
         │
         ▼
Server creates MessageReaction entity
         │
         ▼
Client fetches updated messages
         │
         ▼
ReactionsRow displays grouped reactions
```

### Data Flow - Read Receipts

```
Client fetches messages
         │
         ▼
Identify unread messages (not in readBy array)
         │
         ▼
POST /match/messages/read
   { "messageIds": [...] }
         │
         ▼
Server adds userId to readBy array
         │
         ▼
Partner's next fetch shows blue checkmark
```

### Data Flow - Typing Indicators

```
User types in TextField
         │
         ▼
onChange triggers userIsTyping()
         │
         ▼
Debounce check (2 second cooldown)
         │
         ▼
POST /match/typing { "isTyping": true }
         │
         ▼
Server creates/updates TypingIndicator entity
         │
         ▼
Partner's next poll includes partnerIsTyping: true
         │
         ▼
TypingIndicatorView displays animated dots
```

### Database Entities

#### MessageReaction
Key format: `{messageId}_{userId}_{emoji}`
```python
{
    'messageId': str,       # Message being reacted to
    'matchId': str,         # For querying all reactions in a match
    'userId': str,          # User who reacted
    'emoji': str,           # One of: 👍, ❤️, 😂, 😮, 😢
    'createdAt': str        # ISO timestamp
}
```

#### TypingIndicator
Key format: `{matchId}_{userId}`
```python
{
    'matchId': str,         # The match context
    'userId': str,          # User who is typing
    'isTyping': bool,       # Current typing state
    'updatedAt': str        # ISO timestamp (expires after 5 seconds)
}
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| /match/messages/{id}/reactions | POST | Add reaction to message |
| /match/messages/{id}/reactions/{emoji} | DELETE | Remove reaction |
| /match/messages/read | POST | Mark messages as read |
| /match/typing | POST | Update typing status |
| /match/typing | GET | Get partner's typing status |

See [API.md](../API.md) for detailed request/response formats.

## UI Components

### TypingIndicatorView
- Displays at bottom of message list when `partnerIsTyping` is true
- Shows 3 animated dots that bounce sequentially
- Styled like a received message bubble (gray background, left-aligned)

### ReactionPickerSheet
- Bottom sheet (120pt height) with 5 emoji buttons
- Highlights emojis user has already selected
- Dismisses after selection or cancel

### ReactionsRow
- Horizontal row of grouped reactions below message bubble
- Each reaction shows emoji and count (if > 1)
- Pill-shaped background for each reaction group

### MessageBubble Updates
- Long-press gesture triggers reaction picker
- Shows ReactionsRow if message has reactions
- Shows checkmark next to timestamp for sent messages
- Checkmark color indicates read status (gray/blue)

## Test Cases

### Unit Tests

1. **TC-1**: Adding reaction creates MessageReaction entity
2. **TC-2**: Removing reaction deletes correct entity
3. **TC-3**: Duplicate reactions are prevented (same user, same emoji)
4. **TC-4**: Read receipts update readBy array
5. **TC-5**: Typing indicator expires after 5 seconds
6. **TC-6**: Only allowed emojis are accepted

### Integration Tests

1. **TC-7**: User A reacts, User B sees reaction on next poll
2. **TC-8**: User A sends message, User B reads, User A sees blue checkmark
3. **TC-9**: User A types, User B sees typing indicator
4. **TC-10**: Typing indicator disappears when User A stops typing

### UI Tests

1. **TC-11**: Long-press opens reaction picker
2. **TC-12**: Selecting emoji dismisses picker and updates UI
3. **TC-13**: Typing in TextField shows indicator on partner's device
4. **TC-14**: Reactions display correctly grouped with counts

## Future Enhancements

1. Custom reaction emojis
2. Reaction notifications
3. Double-tap to like (quick reaction)
4. Message delivery receipts (single vs double checkmark)
5. Real-time updates via WebSockets (replace polling)
6. Reaction animations
