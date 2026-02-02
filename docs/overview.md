# PokeMe - Application Overview

## Concept

PokeMe is a college-campus social app designed to help students make meaningful connections. Each day, users are paired with a random, different student from their campus. The goal is to encourage organic social interactions and help students expand their social circles.

## Core Features

### Daily Pairing
- Users receive one random match per day
- Optional filters (like major) can influence matching
- If a user disconnects from their match, they must wait until the next day for a new one

### Social Interactions
- **Chat**: Message your daily match
- **Photos**: Share photos with a cooldown mechanic
- **Pokes**: Send pokes to your match (costs social points)

### Gamification
- **Social Points**: Earned through interactions, spent on features like pokes
- **Starting Balance**: 100 points for new users
- **Leaderboards**: Compete with other users (future feature)
- **Side Quests**: Complete challenges for rewards (future feature)

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
│   ├── match.py            # Matching algorithm
│   ├── app.yaml            # App Engine config
│   └── tests/              # Pytest tests
└── proposal.md             # Original proposal
```
