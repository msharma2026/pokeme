# PokeMe - Application Overview

## Concept

PokeMe is a college-campus social app designed to help students make meaningful connections. Each day, users are paired with a random, different student from their campus. The goal is to encourage organic social interactions and help students expand their social circles.

## Core Features

### Discovery & Matching
- Browse other users' profiles, filtered by sport
- Poke users you're interested in playing with
- Mutual pokes create a match with a chat channel

### Flexible Availability
- Set availability using shortcuts (Morning/Afternoon/Evening) per day
- Add specific hour ranges (e.g., 2 PM - 4 PM on Monday)
- Stored as `[String: [String]]` dict — values can be shortcuts or "HH:00" strings

### Compatible Playtimes & Sessions
- View overlapping availability and shared sports with a match
- Propose play sessions (sport, day, time, location) directly from chat
- Session proposals appear as interactive cards in chat with Accept/Decline buttons
- Track upcoming accepted sessions

### Public Meetups
- Create public meetups for any sport with date, time, location, skill levels, and player limit
- Browse and filter meetups by sport
- Join or leave meetups; hosts can cancel
- Dedicated "Meetups" tab in the app

### Chat
- Real-time messaging with matched users
- Message reactions, read receipts, typing indicators
- Session proposal cards inline in chat

## Technology Stack

| Component | Technology |
|-----------|------------|
| iOS Client | Swift + SwiftUI |
| Backend | Python + Flask |
| Database | Google Cloud Datastore |
| Hosting | Google App Engine |
| Authentication | JWT |

## Architecture Overview

```
┌──────────────────┐     HTTPS/JSON     ┌──────────────────┐
│    iOS App       │◄──────────────────►│   Flask API      │
│   (SwiftUI)      │                    │  (Python)        │
└──────────────────┘                    └────────┬─────────┘
                                                 │
                                        Google App Engine
                                                 │
                                                 ▼
                                        ┌──────────────────┐
                                        │   Datastore      │
                                        │   (Google Cloud) │
                                        └──────────────────┘
```

## User Flow

1. **Registration**: User creates account with email, password, display name, and optional major
2. **Login**: User authenticates and receives JWT token
3. **Daily Match**: User requests today's match
   - If match exists: Shows partner info
   - If in pool: Shows "waiting" message
   - If disconnected: Shows "wait until tomorrow"
4. **Interaction**: User can chat, poke, or disconnect from match

## Milestone 0 Scope

For the initial milestone, we implement:
- User registration and authentication
- Daily pairing algorithm
- Basic iOS app with login, register, and match display
- Server with auth and matching endpoints

## Project Structure

```
pokeme/
├── docs/                    # Documentation
├── ios/PokeMe/             # iOS application
│   └── PokeMe/
│       ├── App/            # App entry point
│       ├── Models/         # Data models
│       ├── ViewModels/     # Business logic
│       ├── Views/          # SwiftUI views
│       └── Services/       # API services
├── server/                  # Python Flask backend
│   ├── main.py             # Flask app entry
│   ├── auth.py             # Auth routes & logic
│   ├── match.py            # Matching, messaging, sessions
│   ├── meetup.py           # Public meetups blueprint
│   ├── models.py           # Entity helpers (user, session, meetup)
│   ├── app.yaml            # App Engine config
│   └── tests/              # Pytest tests
└── proposal.md             # Original proposal
```
