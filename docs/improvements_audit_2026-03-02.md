# PokeMe Improvement Audit (March 2, 2026)

## Scope Reviewed
- iOS app (`ios/PokeMe/PokeMe`): all Views, ViewModels, Services, Models, Utilities
- Backend (`server`): all routes, models, auth/middleware, recommendation logic, tests, deploy config
- Project docs (`README.md`, `docs/`, `docs/features/`)

## Current Feature Inventory

### Implemented End-to-End
- Auth: email/password login + phone verification login
- Profiles: editable profile, sports/skill levels, availability, profile pictures, social handles
- Discovery: sport filters, compatibility scoring, poke flow
- Matching: mutual poke creates private match
- 1:1 Chat: polling-based chat, message reactions, typing indicator, read receipts
- Session proposals: propose/accept/decline play sessions in chat
- Public meetups: create/list/join/leave/cancel + meetup group chat
- Local notifications: new pokes, matches, meetup joins, message polling
- Settings: appearance mode, notifications toggle, test-data reset

### Partially Implemented / Inconsistent
- Recommendation engine: both server and client score logic exist (duplication)
- Notification strategy: mixed NotificationManager usage vs direct UNUserNotificationCenter calls
- Docs/tests: still include old daily-pairing APIs that are no longer in backend

## High-Priority Improvements (Stability + Correctness)

### 1) Align API docs/tests with actual backend
- Problem: docs and tests reference removed endpoints (`/api/match/today`, `/api/match/disconnect`) and old flows.
- Why it matters: onboarding friction, false test failures, confusion for contributors.
- Where to change:
  - `docs/API.md`
  - `docs/server_architecture.md`
  - `docs/features/daily_pairing.md` (archive or rewrite)
  - `server/tests/test_auth.py`
  - `server/tests/test_recommendation.py` (also imports missing symbol)
- Suggested action:
  - Replace with current endpoints under `/discover`, `/poke/<id>`, `/matches/*`, `/meetups/*`.
  - Remove/rename stale daily-pairing docs if feature is retired.

### 2) Remove client/server scoring divergence
- Problem: discover ranking is computed server-side and also recalculated client-side in `DiscoverViewModel`.
- Why it matters: users may see score/reason inconsistencies; harder to maintain and experiment.
- Where to change:
  - iOS: `ViewModels/DiscoverViewModel.swift`
  - Server: `server/recommendation.py`, `server/match.py` (`discover`)
- Suggested action:
  - Make server the single source of truth for ranking/scoring.
  - Keep client fallback only as a guarded offline mode with clear flagging.

### 3) Add concurrency safety for poke/join operations
- Problem: mutual poke and meetup join operations are vulnerable to race conditions because they use read-then-write without transaction semantics.
- Why it matters: duplicate match creation, participant overflow edge cases.
- Where to change:
  - `server/match.py` (`poke`)
  - `server/meetup.py` (`join_meetup`, `leave_meetup`, possibly `cancel_meetup`)
- Suggested action:
  - Use Datastore transactions for critical sections.
  - Enforce idempotency keys or deterministic match key for mutual poke handshake.

### 4) Improve backend query efficiency for scale
- Problem: some endpoints fetch large datasets and filter/sort in memory.
- Why it matters: response latency and cost increase rapidly with user growth.
- Hot spots:
  - `server/match.py::discover()` loads all users and filters in Python
  - `server/match.py::get_matches()` loads all messages per match to find last message
  - `server/meetup.py::list_meetups()` filtering mostly post-query
- Suggested action:
  - Add pagination + cursors on list endpoints.
  - Persist `lastMessageAt` and `lastMessagePreview` on Match to avoid message scans.
  - Add index-backed query patterns and tighten filters.

### 5) Harden auth and abuse controls
- Problem: weak operational defaults and missing anti-abuse safeguards.
- Risks observed:
  - Default JWT secret fallback in `server/config.py`
  - Static JWT secret in `server/app.yaml`
  - No password strength policy in `server/auth.py`
  - Phone verification lacks robust rate limiting / resend cooldown policy
  - `/admin/reset` accessible to any authenticated user in `server/match.py`
- Suggested action:
  - Require strong env secrets in production startup checks.
  - Add per-user/per-IP rate limits for auth/phone endpoints.
  - Restrict admin routes by role or environment guard.

## UX/UI Improvements (Current Screens)

### 1) Unify visual system across auth and app
- Observation: `LoginView`/`RegisterView` are plain blue while phone login and main app use orange/pink gradients.
- Impact: inconsistent brand experience and lower perceived polish.
- Where to change:
  - `Views/Auth/LoginView.swift`
  - `Views/Auth/RegisterView.swift`
  - optionally central theme tokens in `Utilities/Constants.swift` (or new `Theme.swift`)

### 2) Reduce repeated mapping/utilities in views
- Observation: sport emoji mapping is duplicated in many views.
- Impact: brittle updates, inconsistent icon behavior.
- Where to change:
  - `Views/Home/DiscoverView.swift`, `MatchCardView.swift`, `MatchesListView.swift`
  - `Views/Meetups/MeetupSportPickerView.swift`, `MeetupDetailView.swift`
  - `Views/Profile/ProfileView.swift`
- Suggested action:
  - Add `SportPresentation` helper (`emoji`, optional SF Symbol, gradient).

### 3) Improve chat UX for long threads
- Observation: polling every 3s + full message refetch + no pagination.
- Impact: battery/network usage, choppy scroll for long chats.
- Where to change:
  - iOS: `ViewModels/ChatViewModel.swift`, `Views/Chat/ChatView.swift`
  - Server: `server/match.py` message routes
- Suggested action:
  - Add message pagination (`before`, `limit`) and incremental updates.
  - Move to WebSocket/SSE for typing/messages if feasible.

### 4) Accessibility pass
- Observation: many color-dependent cues and small text; minimal accessibility modifiers.
- Impact: weaker usability for VoiceOver/dynamic type/reduced motion users.
- Where to change:
  - All major views, especially `DiscoverCardView`, `ChatView`, `MeetupCardView`, `ProfileView`
- Suggested action:
  - Add `accessibilityLabel`/`Hint`, dynamic type checks, contrast audit.
  - Respect `Reduce Motion` and tone down always-on animations.

### 5) Profile edit UX clarity
- Observation: `EditProfileView` is very dense and mixes account basics, sports, availability, socials in one form.
- Impact: high cognitive load and lower completion rates.
- Where to change:
  - `Views/Profile/EditProfileView.swift`
  - optionally split into multi-step sheets/subviews
- Suggested action:
  - Break into sections with progress (Basics, Sports, Availability, Socials).
  - Add profile-completeness indicator to drive completion.

## Engineering Improvements (Medium Priority)

### 1) Centralize polling lifecycle
- Problem: several independent timers (`MatchViewModel`, `PokesViewModel`, `ChatViewModel`, `MeetupChatViewModel`, `MeetupViewModel`, `MessageNotificationPoller`).
- Impact: duplicate work, lifecycle bugs, network overhead.
- Where to change:
  - All above ViewModels + `HomeView.swift`
- Suggested action:
  - Introduce a shared polling coordinator and app foreground/background awareness.

### 2) Standardize error handling and user-facing copy
- Problem: many generic errors (`"Failed to ..."`) and silent catch blocks.
- Where to change:
  - `ViewModels/*`, `Services/NetworkService.swift`
- Suggested action:
  - Create typed domain errors + consistent friendly messaging.
  - Log hidden errors for diagnostics.

### 3) Move images out of Datastore entity payloads
- Problem: base64 profile pictures stored directly in user entity.
- Impact: larger payloads, datastore limits/index concerns, slower responses.
- Where to change:
  - `server/auth.py` (`upload_profile_picture`)
  - iOS decode points in views
- Suggested action:
  - Use Cloud Storage URLs + image resizing variants.

### 4) Add observability basics
- Problem: minimal structured logging/metrics around critical flows.
- Where to change:
  - `server/main.py`, route modules
- Suggested action:
  - Structured logs for auth failures, poke/match creation, meetup joins, latency buckets.

## New Feature Opportunities (Product)

### 1) Trust & safety layer (highest product priority)
- Add block/report flow and simple moderation queue.
- Why: matching/social features need safety controls for retention and campus adoption.
- Where to change:
  - Backend: new `reports` and `blocks` routes + query filters in discover/messaging
  - iOS: action menus in `ChatView`, `DiscoverCardView`, `MeetupDetailView`

### 2) Reliability score for players
- Add profile metric based on session acceptance rate, meetup attendance, and no-show reports.
- Why: addresses commitment mismatch from user interviews.
- Where to change:
  - Backend: derive/store reliability fields on `User`
  - iOS: display badges in discover/match/meetup cards

### 3) Waitlist + auto-fill for full meetups
- Let users queue for full meetups and auto-promote when spots open.
- Where to change:
  - `server/meetup.py`, `Models/Meetup.swift`, `MeetupDetailView.swift`, `MeetupCardView.swift`

### 4) Calendar integration for accepted sessions/meetups
- Add one-tap add-to-calendar and reminders.
- Where to change:
  - iOS: `EventKit` integration in `SessionProposalBubble` and `MeetupDetailView`
  - Backend optional: reminder scheduling metadata

### 5) Location quality upgrades
- Support map pin/place picker and distance hints.
- Where to change:
  - iOS: `CreateMeetupView.swift`, `MeetupDetailView.swift`
  - Backend: store normalized place metadata (`lat/lng`, placeId)

### 6) Group-first discovery mode
- Enable finding small groups (2-4 players) based on sport/time overlap.
- Why: directly addresses interview preference for group interactions over strict 1:1.
- Where to change:
  - Backend: new matching/recommendation endpoint
  - iOS: new tab or discover mode toggle

## Suggested Execution Plan

### Phase 1 (1-2 weeks): Correctness + hygiene
- Align docs/tests with live APIs
- Remove ranking duplication
- Harden admin/auth guards
- Add minimal query/index improvements and pagination for critical list endpoints

### Phase 2 (2-4 weeks): UX and performance
- Unify design system and shared sport presentation helper
- Refactor polling architecture
- Chat pagination/incremental updates
- Accessibility improvements

### Phase 3 (4-8 weeks): Growth features
- Trust & safety (block/report)
- Reliability score
- Waitlists + calendar integration
- Group-first discovery experiments

## Quick Wins (Low Effort, High Impact)
- Extract duplicated sport emoji logic into one utility
- Replace silent `catch {}` blocks with lightweight logging
- Tighten `/admin/reset` access
- Add query parameter encoding in `MeetupService.getMeetups` for sport/date
- Standardize notification sending via `NotificationManager`

## Known Risks if Unaddressed
- Contributor confusion due stale docs/tests
- Scaling bottlenecks from in-memory filtering and repeated polling
- Trust/safety gaps for campus social product
- Inconsistent recommendation behavior from dual scoring paths

## Additional Design Changes (Requested Follow-Up)

### 1) Introduce a cohesive design token system
- Add shared color/spacing/radius/shadow/typography tokens instead of inline styling.
- Why: speeds up iteration and removes visual drift across tabs.
- Where to change:
  - Add `ios/PokeMe/PokeMe/Utilities/Theme.swift`
  - Replace repeated gradients and corner radii in all major `Views/*`

### 2) Upgrade information hierarchy on Discover cards
- Move from "large media-first card" to "decision-first card":
  - top row: name, reliability badge, compatibility percent
  - middle: shared sports + shared windows chips
  - bottom: primary CTA (`Poke`) + secondary (`View Full Profile`)
- Why: faster scan/decision behavior, better on smaller phones.
- Where to change:
  - `Views/Home/MatchCardView.swift` (`DiscoverCardView`)
  - `ViewModels/DiscoverViewModel.swift` (ensure fields needed for quick summary)

### 3) Add empty-state and loading-state design system
- Standardize empty states by scenario (no profiles, no matches, no meetups, no messages).
- Include clear action path on each state (`Refresh`, `Edit profile`, `Create meetup`, etc.).
- Where to change:
  - `Views/Home/DiscoverView.swift`
  - `Views/Home/MatchesListView.swift`
  - `Views/Meetups/MeetupsListView.swift`
  - `Views/Meetups/MeetupChatView.swift`

### 4) Add motion guidelines and reduce animation noise
- Current UI has many independent animations (pulses, bounces, gradients).
- Introduce 2-3 canonical animation styles: entrance, emphasis, state change.
- Respect reduced-motion globally.
- Where to change:
  - Create reusable animation presets in `Theme.swift`
  - Apply in `PhoneLoginView`, `DiscoverCardView`, `TypingIndicatorView`, `ProfileView`

### 5) Improve tab/navigation model for clarity
- Consider this order for task frequency:
  - Discover, Matches, Meetups, Pokes, Profile
- Add persistent "new activity" indicators at tab level (messages/pokes/meetup updates).
- Where to change:
  - `Views/Home/HomeView.swift`
  - `ViewModels/MatchViewModel.swift`, `PokesViewModel.swift`, `MeetupViewModel.swift`

### 6) Add trust cues in UI components
- Show quick trust markers on cards:
  - profile completion %
  - verified school email / verified phone
  - reliability score
  - report/block access in context menus
- Where to change:
  - `Views/Home/DiscoverView.swift`
  - `Views/Home/MatchesListView.swift`
  - `Views/Meetups/MeetupDetailView.swift`
  - model additions in `Models/User.swift`

## Additional Feature Ideas (Requested Follow-Up)

### 1) Smart "Now" mode (spontaneous play)
- New mode for users available in the next 2-3 hours.
- Filters by current location proximity + current availability overlap.
- Suggested implementation:
  - Backend: new endpoint `/discover/now` with stricter time/location weighting
  - iOS: toggle in `DiscoverView` and new chip in `MeetupsListView`

### 2) Recurring squad feature
- Convert successful one-off sessions into recurring weekly squads.
- Includes attendance tracking and lineup management.
- Suggested implementation:
  - Backend: new entities (`Squad`, `SquadMembership`, `SquadSession`)
  - iOS: new `Squads` section under Meetups or Matches

### 3) Skill progression and coaching mode
- Users can choose "competitive", "casual", or "learn" intent per sport.
- Match learner users with mentors or similar-level players.
- Suggested implementation:
  - Add intent fields to `sports` entries in profile
  - Incorporate into `recommendation.py` scoring and discover reasons

### 4) Post-session feedback loop
- Lightweight rating after accepted sessions/meetups:
  - reliability (showed up?)
  - vibe
  - skill match accuracy
- Feed into recommendation and safety signals.
- Suggested implementation:
  - Backend: `SessionFeedback` entity and aggregate fields on `User`
  - iOS: prompt in chat/meetup detail after scheduled time passes

### 5) Team split and auto-balancer for meetups
- For team sports, auto-generate balanced teams from participant skill levels.
- Useful right before game start.
- Suggested implementation:
  - Backend utility on meetup participants + sports skill levels
  - iOS action button in `MeetupDetailView` for host

### 6) Availability sync with calendar constraints
- Optional read-only sync with user calendar busy times.
- App suggests play windows that avoid conflicts.
- Suggested implementation:
  - iOS: EventKit permission + local busy window extraction
  - Backend: send normalized busy blocks with availability updates

### 7) Campus/facility-aware meetup templates
- Quick templates by location:
  - ARC Courts, Hutchison Fields, Tennis Complex, etc.
- Auto-fills title, duration, player limits, and sport defaults.
- Suggested implementation:
  - iOS: template picker in `CreateMeetupView`
  - Backend: optional template config endpoint for remote tuning

### 8) Better re-engagement loops
- Add "nudge" actions when users go inactive:
  - suggest 3 nearby active meetups
  - suggest 3 high-compatibility people with open availability
- Suggested implementation:
  - Backend cron/recommendation job
  - iOS push/local notification deep links to specific tabs

### 9) Match memory and continuity
- Show shared history with a user:
  - previous sessions played
  - accepted/declined proposal ratio
  - preferred sports/times together
- Suggested implementation:
  - Backend aggregates on `Match` entity
  - iOS display in `ChatView` header and `MatchesListView` row metadata

### 10) Safer onboarding for new users
- First-run guided setup with minimum trust threshold before appearing in Discover:
  - profile photo
  - at least one sport and skill level
  - at least two availability blocks
- Suggested implementation:
  - iOS onboarding flow before `HomeView`
  - Backend discover filter excludes incomplete profiles unless opted-in
