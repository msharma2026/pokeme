# Public Meetups

## Overview
Allows users to create and join public sports events (meetups) with other users. Provides a discoverable feed of upcoming meetups filtered by sport, location, and skill level.

## Data Model

### Meetup Entity
Represents a public sports event:
- `id`: Unique identifier
- `hostId`: User who created the meetup
- `sport`: Type of sport
- `title`: Event name/description
- `date`: Date of the meetup
- `time`: Time in HH:00 format
- `location`: Meeting location string
- `skillLevels`: Array of accepted skill levels (e.g., ["Beginner", "Intermediate"])
- `playerLimit`: Maximum number of participants (including host)
- `participants`: Array of user IDs currently joined
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

## API Endpoints

### POST /meetups
Create a new meetup:
- **Request**: `{sport, title, date, time, location, skillLevels, playerLimit}`
- **Response**: Created meetup object
- **Auth**: Requires authenticated user (becomes host)

### GET /meetups
List all public meetups:
- **Query**:
  - `sport` (optional): Filter by sport
  - `date` (optional): Filter by specific date or date range
  - `location` (optional): Keyword search in location
- **Response**: Array of meetup objects with participant count

### GET /meetups/mine
List meetups created by or joined by authenticated user:
- **Response**: Array of meetup objects

### POST /meetups/<id>/join
Join an existing meetup:
- **Preconditions**: User's skill level in required list, participants < playerLimit
- **Response**: Updated meetup object with user added to participants
- **Error**: 400 if full or skill level not accepted

### POST /meetups/<id>/leave
Leave a joined meetup:
- **Preconditions**: User must be a participant (not host)
- **Response**: Updated meetup object with user removed
- **Error**: 400 if user is host

### DELETE /meetups/<id>
Cancel/delete a meetup:
- **Auth**: Only host can delete
- **Response**: Success confirmation

## iOS Implementation

### Meetups Tab (5th Tab)
New primary navigation tab featuring:
- Sport filter pills at top (Basketball, Soccer, Volleyball, etc.)
- Upcoming meetups list below filters
- "Create Meetup" floating action button

### MeetupsListView
Main feed component:
- Displays all meetups matching selected sport filter
- Pull-to-refresh to sync with backend
- Tapping a meetup navigates to detail view

### MeetupCardView
Card component for list items:
- Sport icon/badge
- Title and location
- Date and time
- "X/Y players joined" progress indicator
- Quick join button (if eligible)

### CreateMeetupView
Form for creating new meetup:
- Sport selector dropdown
- Title text field
- Date and time pickers
- Location text field
- Skill level checkboxes
- Player limit number picker
- Create button validates and posts to backend

### MeetupDetailView
Full details for a meetup:
- All meetup information
- List of participants with skill levels
- Host name/profile
- Join/Leave button (conditional)
- Edit/Delete buttons (if current user is host)
- Messages/comments section (optional)

## Workflow
1. User navigates to Meetups tab
2. Selects sport filter (or views all)
3. Sees list of upcoming meetups
4. Can tap to view details or quick-join from card
5. Joined meetups appear in /meetups/mine
6. Can create new meetup via "Create Meetup" form
