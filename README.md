# PokeMe

A sports-based social app that connects college students who want to play sports together. Discover players by sport, poke to connect, chat, propose play sessions, and organize public meetups.

## Quick Start

### 1. Deploy the Server

```bash
cd server
gcloud auth login
gcloud config set project pokeme-191
gcloud app deploy
```

Server URL: `https://pokeme-191.uw.r.appspot.com`

### 2. Build and Run the iOS App

```bash
open ios/PokeMe/PokeMe.xcodeproj
```

Or from the command line:

```bash
cd ios/PokeMe
xcodebuild -scheme PokeMe -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 3. Test with Two Simulators

```bash
xcrun simctl boot "iPhone 17"
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
```

### 4. Login with Test Phone Numbers

| Phone Number    | Code   | Name       |
|-----------------|--------|------------|
| +15305550000    | 123456 | User 0000  |
| +15305550002    | 654321 | User 0002  |
| +15305550003    | 111111 | User 0003  |
| +15305550007    | 222222 | User 0007  |
| +15305550008    | 333333 | User 0008  |

Error testing numbers: `+15305550001` (invalid phone), `+15305550004` (invalid code).

## Features

- **Discover**: Browse players filtered by sport (Basketball, Tennis, Soccer, Volleyball, etc.) with skill levels and weekly availability
- **Poke**: Send a poke to someone you want to play with. Mutual pokes create a match with a private chat
- **Incoming Pokes**: See who has poked you and poke them back
- **Chat**: Real-time messaging with reactions, read receipts, and typing indicators
- **Session Proposals**: Propose play sessions (sport, day, time, location) directly in chat. Partners can accept or decline
- **Public Meetups**: Create or join open meetups with date, time, location, skill level, and player limits
- **Availability**: Set your weekly schedule with morning/afternoon/evening blocks or specific hours. The app computes compatible playtimes between matched users
- **Dark Mode**: System, light, or dark appearance
- **Notifications**: Local notifications for new pokes, matches, and messages
- **Settings**: Appearance, notifications, and a reset button for clearing test data

## Project Structure

```
pokeme/
├── server/          # Python Flask backend (Google App Engine)
│   ├── main.py      # App entry point
│   ├── match.py     # Discovery, pokes, matches, messaging, sessions
│   ├── meetup.py    # Public meetups
│   ├── auth.py      # Authentication & profiles
│   └── phone_auth.py # Phone verification
├── ios/PokeMe/      # SwiftUI iOS app
│   └── PokeMe/
│       ├── App/           # App entry point
│       ├── Models/        # Data models
│       ├── Views/         # UI (Discover, Chat, Meetups, Profile, Settings)
│       ├── ViewModels/    # Business logic
│       ├── Services/      # API clients
│       └── Utilities/     # Constants, helpers, notifications
└── docs/            # Documentation
```

## Tech Stack

- **iOS**: SwiftUI
- **Server**: Python + Flask
- **Database**: Google Cloud Datastore
- **Hosting**: Google App Engine
- **Auth**: JWT tokens

## API Endpoints

Base URL: `https://pokeme-191.appspot.com/api`

### Authentication
| Method | Endpoint              | Description                |
|--------|-----------------------|----------------------------|
| POST   | /phone/send-code      | Send verification code     |
| POST   | /phone/verify-code    | Verify code and login      |
| POST   | /auth/register        | Register with email        |
| POST   | /auth/login           | Login with email           |
| GET    | /auth/me              | Get current user           |
| PUT    | /auth/profile         | Update profile             |
| POST   | /auth/profile-picture | Upload profile picture     |

### Discovery & Pokes
| Method | Endpoint              | Description                      |
|--------|-----------------------|----------------------------------|
| GET    | /discover?sport=X     | Browse profiles, filter by sport |
| POST   | /poke/:userId         | Poke a user (mutual = match)     |
| GET    | /pokes/incoming       | Get incoming pokes               |

### Matches & Messaging
| Method | Endpoint                                    | Description             |
|--------|---------------------------------------------|-------------------------|
| GET    | /matches                                    | Get all matches         |
| GET    | /matches/:id/messages                       | Get chat messages       |
| POST   | /matches/:id/messages                       | Send a message          |
| POST   | /matches/:id/messages/:msgId/reactions      | Add reaction            |
| DELETE | /matches/:id/messages/:msgId/reactions/:emoji | Remove reaction       |
| POST   | /matches/:id/messages/read                  | Mark messages as read   |
| POST   | /matches/:id/typing                         | Update typing status    |
| GET    | /matches/:id/typing                         | Get typing status       |

### Sessions
| Method | Endpoint                          | Description                    |
|--------|-----------------------------------|--------------------------------|
| GET    | /matches/:id/compatible-times     | Get overlapping availability   |
| POST   | /matches/:id/sessions             | Propose a play session         |
| PUT    | /matches/:id/sessions/:sessionId  | Accept or decline              |
| GET    | /matches/:id/sessions             | List sessions for a match      |
| GET    | /sessions/upcoming                | All accepted upcoming sessions |

### Meetups
| Method | Endpoint              | Description                    |
|--------|-----------------------|--------------------------------|
| POST   | /meetups              | Create a meetup                |
| GET    | /meetups?sport=&date= | List meetups (with filters)    |
| GET    | /meetups/mine         | Get hosted/joined meetups      |
| POST   | /meetups/:id/join     | Join a meetup                  |
| POST   | /meetups/:id/leave    | Leave a meetup                 |
| DELETE | /meetups/:id          | Cancel meetup (host only)      |

### Admin
| Method | Endpoint                    | Description                      |
|--------|-----------------------------|----------------------------------|
| POST   | /admin/reset                | Reset all pokes & matches (test) |
| GET    | /admin/debug-discover?sport=| Debug discover filtering         |

## Server Setup

### Local Development

```bash
cd server
pip install -r requirements.txt
python main.py
```

Server runs at `http://localhost:8080`

### Deploy

```bash
cd server
gcloud app deploy
```

## Prerequisites

- **Server**: Python 3.9+, Google Cloud SDK
- **iOS**: Xcode 16+, macOS
