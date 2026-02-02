# PokeMe

A social iOS app that pairs college students daily for spontaneous connections.

## Quick Start

### 1. Deploy the Server (if not already deployed)

```bash
cd server
gcloud auth login
gcloud config set project pokeme-191
gcloud app deploy
```

Server URL: `https://pokeme-191.uw.r.appspot.com`

### 2. Build and Run the iOS App

```bash
# Open in Xcode
open ios/PokeMe/PokeMe.xcodeproj

# Or build from command line
cd ios/PokeMe
xcodebuild -scheme PokeMe -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 3. Test with Two Simulators

```bash
# Boot both simulators
xcrun simctl boot "iPhone 17"
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator

# Install app on both
xcrun simctl install "iPhone 17" ~/Library/Developer/Xcode/DerivedData/PokeMe-*/Build/Products/Debug-iphonesimulator/PokeMe.app
xcrun simctl install "iPhone 17 Pro" ~/Library/Developer/Xcode/DerivedData/PokeMe-*/Build/Products/Debug-iphonesimulator/PokeMe.app

# Launch on both
xcrun simctl launch "iPhone 17" com.pokeme.app
xcrun simctl launch "iPhone 17 Pro" com.pokeme.app
```

### 4. Login with Test Phone Numbers

On **iPhone 17**:
- Phone: `+15305550007`
- Code: `222222`

On **iPhone 17 Pro**:
- Phone: `+15305550008`
- Code: `333333`

Both users will automatically be matched together!

---

## Project Structure

```
pokeme/
├── server/          # Python Flask backend (deployed to Google App Engine)
├── ios/PokeMe/      # SwiftUI iOS application
└── docs/            # Documentation
```

## Prerequisites

- **Server**: Python 3.9+, Google Cloud SDK
- **iOS**: Xcode 15+, macOS

## Test Phone Numbers

For development, use these test phone numbers. Each test phone can only have one active match per day - if you disconnect, use a different test number.

| Phone Number    | Code   | Description        |
|-----------------|--------|--------------------|
| +15305550000    | 123456 | Test User 1        |
| +15305550002    | 654321 | Test User 2        |
| +15305550003    | 111111 | Test User 3        |
| +15305550007    | 222222 | Test User 4        |
| +15305550008    | 333333 | Test User 5        |

**Error Testing:**
| Phone Number    | Behavior           |
|-----------------|--------------------|
| +15305550001    | Invalid phone error|
| +15305550004    | Invalid code error |

**Note:** If two test users have disconnected from each other, they cannot rematch until the next day (midnight Pacific Time). Use different test phone numbers to create a new match.

## Testing Features

### Testing Daily Matching
1. Login with two different test phones on two simulators
2. Both users will be matched automatically
3. You'll see your match's name and can interact with them

### Testing Poke Feature
1. Tap the orange "Poke!" button on either simulator
2. The poke count updates in real-time on both devices (refreshes every 5 seconds)

### Testing Chat
1. Tap the blue "Chat" button to open messaging
2. Send messages from either device
3. Messages sync automatically every 3 seconds

### Testing Profile
1. Tap the profile icon (top right) > "Profile"
2. Tap "Edit" to update your profile
3. You can add:
   - Profile picture (from photo library)
   - Display name and major
   - Bio
   - Social media links (Instagram, Twitter/X, Snapchat, LinkedIn)

### Testing Disconnect
1. Tap "Disconnect" to end the current match
2. You'll see "See you tomorrow!" message
3. A new match will be available at midnight Pacific Time

## Server Setup

### Local Development

1. Navigate to the server directory:
   ```bash
   cd server
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run locally (requires Google Cloud credentials):
   ```bash
   python main.py
   ```
   Server runs at `http://localhost:8080`

### Deploy to Google App Engine

1. Authenticate with Google Cloud:
   ```bash
   gcloud auth login
   ```

2. Set your project:
   ```bash
   gcloud config set project pokeme-191
   ```

3. Deploy:
   ```bash
   cd server
   gcloud app deploy
   ```

   Server URL: `https://pokeme-191.uw.r.appspot.com`

## iOS App Setup

### Build and Run in Xcode

1. Open the project in Xcode:
   ```bash
   open ios/PokeMe/PokeMe.xcodeproj
   ```

2. Select a simulator (iPhone 17 recommended) and press `Cmd+R` to build and run.

### Build from Command Line

1. Build the app:
   ```bash
   cd ios/PokeMe
   xcodebuild -scheme PokeMe -destination 'platform=iOS Simulator,name=iPhone 17' build
   ```

2. Boot the simulator:
   ```bash
   xcrun simctl boot "iPhone 17"
   open -a Simulator
   ```

3. Install and launch:
   ```bash
   xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/PokeMe-*/Build/Products/Debug-iphonesimulator/PokeMe.app
   xcrun simctl launch booted com.pokeme.app
   ```

### Running Multiple Simulators

1. Boot a second simulator:
   ```bash
   xcrun simctl boot "iPhone 17 Pro"
   ```

2. Install app on second simulator:
   ```bash
   xcrun simctl install "iPhone 17 Pro" ~/Library/Developer/Xcode/DerivedData/PokeMe-*/Build/Products/Debug-iphonesimulator/PokeMe.app
   xcrun simctl launch "iPhone 17 Pro" com.pokeme.app
   ```

## API Endpoints

Base URL: `https://pokeme-191.uw.r.appspot.com/api`

### Authentication
| Method | Endpoint              | Description                |
|--------|-----------------------|----------------------------|
| POST   | /phone/send-code      | Send verification code     |
| POST   | /phone/verify-code    | Verify code and login      |
| POST   | /auth/register        | Register with email        |
| POST   | /auth/login           | Login with email           |
| GET    | /auth/me              | Get current user           |
| PUT    | /auth/profile         | Update user profile        |
| POST   | /auth/profile-picture | Upload profile picture     |

### Matching & Messaging
| Method | Endpoint              | Description                |
|--------|-----------------------|----------------------------|
| GET    | /match/today          | Get today's match          |
| POST   | /match/poke           | Poke your match            |
| POST   | /match/disconnect     | Disconnect from match      |
| GET    | /match/messages       | Get messages for match     |
| POST   | /match/messages       | Send a message             |

## Features

- **Phone Authentication**: Login with phone number verification
- **Daily Pairing**: Get matched with a new person each day at midnight Pacific Time
- **Poke**: Send pokes to your daily match (real-time updates every 5 seconds)
- **Chat**: Real-time messaging with your daily match (syncs every 3 seconds)
- **Disconnect**: Skip current match (new match available tomorrow)
- **Profile**: Upload profile picture, add bio, and link social media accounts (Instagram, Twitter/X, Snapchat, LinkedIn)

## Troubleshooting

### "You're in the pool!" but no match
- Make sure another test user is also logged in and waiting
- Refresh by tapping the "Refresh" button

### Messages not syncing
- Make sure the server is deployed and running
- Check that both users are on the same match (not disconnected)

### Can't rematch after disconnect
- Disconnected users can't rematch until the next day
- Use different test phone numbers to create a new match immediately
