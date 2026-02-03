# iOS Client Architecture

## Overview

The PokeMe iOS client is built using SwiftUI with an MVVM (Model-View-ViewModel) architecture pattern. This document describes the structure and design decisions of the iOS application.

## Architecture Pattern: MVVM + Service Layer

```
┌─────────────────────────────────────────────────────────────┐
│                         Views (SwiftUI)                      │
│   LoginView  │  RegisterView  │  HomeView  │  MatchCardView  │
└─────────────────────────┬───────────────────────────────────┘
                          │ @StateObject / @EnvironmentObject
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      ViewModels                              │
│        AuthViewModel         │        MatchViewModel         │
│   - login()                  │   - fetchTodayMatch()         │
│   - register()               │   - disconnect()              │
│   - logout()                 │   - matchState                │
└─────────────────────────┬───────────────────────────────────┘
                          │ async/await calls
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      Services                                │
│   AuthService      │    MatchService      │   NetworkService  │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTP Requests
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Express Server                            │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
PokeMe/
├── App/
│   └── PokeMeApp.swift          # App entry point, auth routing
├── Models/
│   ├── User.swift               # User data model
│   ├── Match.swift              # Match data model
│   ├── Message.swift            # Message, Reaction models and request/response types
│   └── APIResponse.swift        # Generic API response wrapper
├── ViewModels/
│   ├── AuthViewModel.swift      # Authentication state & logic
│   ├── MatchViewModel.swift     # Match state & logic
│   └── ChatViewModel.swift      # Chat state, messaging, reactions, typing
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift      # Login screen
│   │   └── RegisterView.swift   # Registration screen
│   ├── Home/
│   │   ├── HomeView.swift       # Main screen with match
│   │   └── MatchCardView.swift  # Partner info card
│   ├── Chat/
│   │   └── ChatView.swift       # Chat screen with messages, reactions, typing
│   ├── Profile/
│   │   └── (future)
│   └── Components/
│       └── (reusable components)
├── Services/
│   ├── NetworkService.swift     # HTTP client
│   ├── AuthService.swift        # Auth API calls
│   ├── MatchService.swift       # Match API calls
│   └── MessageService.swift     # Message, reaction, typing API calls
├── Utilities/
│   └── Constants.swift          # API URLs, storage keys
└── Resources/
    └── Assets.xcassets
```

## Key Components

### Models

#### User
```swift
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let major: String?
    let socialPoints: Int
    let createdAt: String
}
```

#### Match
```swift
struct Match: Codable, Identifiable {
    let id: String
    let date: String
    let partnerId: String
    let partnerName: String
    let partnerMajor: String?
    let status: String
    let createdAt: String
}
```

### ViewModels

#### AuthViewModel
- Manages authentication state (isAuthenticated, user, token)
- Persists token to UserDefaults
- Provides login(), register(), logout() methods

#### MatchViewModel
- Manages match state using enum:
  - `.loading` - Fetching match
  - `.matched(Match)` - Has an active match
  - `.waiting` - In the matching pool
  - `.disconnected` - Disconnected today
  - `.error(String)` - Error occurred
- Provides fetchTodayMatch(), disconnect() methods

#### ChatViewModel
- Manages chat state:
  - `messages: [Message]` - List of messages
  - `partnerIsTyping: Bool` - Typing indicator state
- Provides methods:
  - `fetchMessages()` - Get messages with reactions and read status
  - `sendMessage()` - Send a new message
  - `addReaction() / removeReaction() / toggleReaction()` - Manage reactions
  - `markUnreadMessagesAsRead()` - Update read receipts
  - `userIsTyping()` - Debounced typing indicator updates
  - `stopTyping()` - Clear typing status
- Polling: Auto-refreshes messages every 3 seconds
- Typing debounce: Sends typing updates max every 2 seconds, auto-stops after 3 seconds

### Services

#### NetworkService
- Singleton HTTP client
- Generic request method with type inference
- Handles authentication headers
- Decodes API responses

#### AuthService
- register(email, password, displayName, major)
- login(email, password)
- getMe(token)

#### MatchService
- getTodayMatch(token)
- disconnect(token)
- poke(token)

#### MessageService
- getMessages(token) - Get messages with reactions and read status
- sendMessage(token, text) - Send a message
- addReaction(token, messageId, emoji) - Add reaction to message
- removeReaction(token, messageId, emoji) - Remove reaction from message
- markMessagesRead(token, messageIds) - Mark messages as read
- updateTyping(token, isTyping) - Update typing status
- getTypingStatus(token) - Get partner's typing status

## State Management

- **@StateObject**: Used for owning ViewModel instances
- **@EnvironmentObject**: Used to pass AuthViewModel through view hierarchy
- **@Published**: Reactive properties in ViewModels

## Navigation Flow

```
App Launch
    │
    ├── Not Authenticated ──► LoginView
    │                              │
    │                              ├── Login Success ──► HomeView
    │                              │
    │                              └── Register Button ──► RegisterView
    │                                                          │
    │                                                          └── Success ──► HomeView
    │
    └── Authenticated ──────────► HomeView
                                      │
                                      └── Logout ──► LoginView
```

## Error Handling

Errors are captured in ViewModels and displayed in Views:
- Network errors (connection, timeout)
- Server errors (validation, not found)
- Auth errors (invalid credentials)

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
