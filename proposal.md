Group name: PokeMe

Kelvin Trinh
Eugene Teng
Teddy Liu
David Arista
Manav Sharma

## PokeMe — Sports Matching App for College Students

### Problem

College students often want to play sports — pickup basketball, tennis, soccer, etc. — but struggle to find others at their skill level with matching availability. Existing platforms like group chats or bulletin boards are disorganized and don't help you find the right people.

### Solution

**PokeMe** is a Tinder-style sports matching app built for college students. Users create profiles listing the sports they play, their skill level, year in college, and when they're free to play. The app shows you other students who play the same sports, and you swipe through their profiles.

- **Swipe right (Poke)**: You want to play with this person.
- **Swipe left (Skip)**: Move on to the next profile.
- **Mutual Poke = Match**: If both users poke each other, it's a match and they can start chatting to set up a game.

### Key Features

1. **Sports Profiles**: Each user lists the sports they play (e.g., Basketball, Tennis, Soccer), their skill level per sport (Beginner, Intermediate, Advanced), their year in college, and their weekly availability.

2. **Tinder-Style Discovery**: Browse one profile at a time. See the person's name, sports, skill levels, year, and availability. Poke to express interest or skip to see the next person.

3. **Smart Filtering**: Filter the discovery feed by sport so you only see people who play what you want to play.

4. **Mutual Matching**: A match is only created when both users poke each other. This ensures both sides are interested before opening a chat.

5. **In-App Messaging**: Once matched, users can chat to coordinate games. The chat supports text messages, emoji reactions, read receipts, and typing indicators.

6. **Phone Number Sign-In**: Simple authentication via phone number verification — no passwords to remember.

### Tech Stack

- **iOS Client**: Swift + SwiftUI (MVVM architecture)
- **Backend**: Python Flask, deployed on Google App Engine
- **Database**: Google Cloud Datastore
- **Authentication**: Phone number verification + JWT tokens

### User Flow

1. Sign in with phone number
2. Set up profile: name, year, sports, skill levels, availability
3. Browse the discovery feed (filtered by sport)
4. Poke profiles you want to play with
5. When a poke is mutual → match created
6. Chat with your match to set up a game

### Target Audience

UC Davis students (and college students in general) looking for sports partners at their campus. The app is designed for casual and recreational sports — not competitive teams or leagues.
