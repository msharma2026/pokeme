# PokeMe Updated UI: Detailed Design and Feature Recommendations (March 2, 2026)

## Context
This document reflects a fresh review of the updated UI screens (Meetups picker, Discover, Pokes empty state, Matches segmented list, Profile, and Edit Profile). The app has improved substantially in consistency and direction. The recommendations below focus on next-level polish, usability, and feature depth.

---

## 1) Product Design Direction (What to optimize for next)

### Core UX goals
- Faster decision-making in Discover (who to poke, why)
- Higher conversion from browsing to action (poke, join, message)
- Better continuity after match/meetup (repeat play)
- Reduced friction in profile completion and settings
- Strong trust/safety confidence for social interactions

### Current strengths to preserve
- Warm athletic gradient identity across key surfaces
- Better card hierarchy compared to earlier versions
- Stronger empty-state CTA in Pokes
- Matches tab segmentation (`All / 1-on-1 / Group`)
- Improved Edit Profile visual organization

---

## 2) Design System Improvements

### 2.1 Visual consistency system
Current issue:
- Similar components still vary in radius, card tint, and spacing rhythm.

Recommendations:
- Standardize radii: `12 (inputs)`, `16 (cards)`, `20 (pill buttons)`.
- Standardize vertical spacing rhythm: `8 / 12 / 16 / 24 / 32`.
- Define surface palette:
  - `Surface/primary` for major cards
  - `Surface/secondary` for grouped blocks
  - `Surface/tinted` for sport/category accents
- Keep one primary CTA gradient and one secondary neutral style.

Implementation targets (iOS):
- Add `Utilities/Theme.swift` (tokens for spacing, radii, colors, shadows, typography).
- Refactor style literals in:
  - `Views/Home/DiscoverView.swift`
  - `Views/Meetups/MeetupSportPickerView.swift`
  - `Views/Home/MatchesListView.swift`
  - `Views/Profile/ProfileView.swift`
  - `Views/Profile/EditProfileView.swift`

### 2.2 Typography and hierarchy
Current issue:
- Headers are strong, but secondary labels are sometimes too faint.

Recommendations:
- Keep page title at one style tier (same size/weight across tabs).
- Increase contrast for supporting text and metadata.
- Ensure skill badges and filter chips remain legible under all modes.

Implementation targets:
- Replace ad-hoc `.foregroundColor(.secondary)` where contrast is weak.
- Add semantic text styles in `Theme.swift` (`title`, `sectionTitle`, `meta`, `chip`).

### 2.3 Motion and feedback
Current issue:
- Some screens still have more animation than needed.

Recommendations:
- Keep animation only for:
  - page transition
  - CTA press feedback
  - badge count updates
- Reduce or remove continuous looping animation on static screens.
- Respect Reduced Motion globally.

Implementation targets:
- Centralize animation presets in `Theme.swift`.
- Audit and simplify motion usage in:
  - `PhoneLoginView`, `DiscoverCardView`, `TypingIndicatorView`, empty states.

---

## 3) Screen-by-Screen UI Recommendations

## 3.1 Meetups sport picker
Observed improvements:
- Strong category framing and better search inclusion.

Further improvements:
1. Make search bar sticky while scrolling categories.
2. Add quick filter row below search:
   - `Today`, `Near me`, `Beginner-friendly`, `Starting soon`.
3. Add one metadata line per sport tile:
   - Example: `23 active this week`.
4. Avoid duplicate sport appearance unless intentional (or label as cross-category).
5. Improve category transitions with subtle separators and section anchors.

Implementation targets:
- `Views/Meetups/MeetupSportPickerView.swift`
- `Views/Meetups/MeetupsListView.swift`
- `ViewModels/MeetupViewModel.swift` (filter state additions)

## 3.2 Discover
Observed improvements:
- Better compatibility card, reason tags, and CTA prominence.

Further improvements:
1. Add secondary quick action below `Poke`: `Skip for now`.
2. Add `Why this match?` bottom sheet for deeper transparency.
3. Add top-right profile action menu: `Hide`, `Report`, `Block`.
4. Make compatibility dial meaningful (tooltip or details when tapped).
5. Compact availability preview with “see full week” expansion.

Implementation targets:
- `Views/Home/DiscoverView.swift`
- `Views/Home/MatchCardView.swift` (`DiscoverCardView`)
- `ViewModels/DiscoverViewModel.swift`
- `Models/User.swift` (optional fields for trust/reliability)

## 3.3 Pokes
Observed improvements:
- Empty-state CTA is much better than previous iteration.

Further improvements:
1. Add secondary CTA: `Improve profile`.
2. Add helper text: profiles with sports + availability are surfaced more.
3. If non-empty, show “new” label and sort by recency + compatibility.
4. Add quick accept/reject gestures for speed.

Implementation targets:
- `Views/Home/IncomingPokesView.swift`
- `ViewModels/PokesViewModel.swift`

## 3.4 Matches
Observed improvements:
- Segmentation is clear and useful.

Further improvements:
1. Add unread indicator dot per row.
2. Show last message preview and relative timestamp.
3. Persist selected segment between app launches.
4. Show empty state per segment (`No group chats yet`).
5. Add pinned chats section.

Implementation targets:
- `Views/Home/MatchesListView.swift`
- `ViewModels/MatchViewModel.swift`
- `Models/Match.swift` (unread count/last message metadata)
- `server/match.py` (send last message + unread count efficiently)

## 3.5 Profile
Observed improvements:
- Header and sectioning are significantly improved.

Further improvements:
1. Add profile completeness ring near avatar.
2. Add reliability badges below year/major.
3. Make sections collapsible for faster scanning.
4. Add “last updated availability” timestamp.

Implementation targets:
- `Views/Profile/ProfileView.swift`
- `ViewModels/ProfileViewModel.swift`
- `Models/User.swift` (completeness/reliability fields)

## 3.6 Edit Profile
Observed improvements:
- Better structuring and readability than previous version.

Further improvements:
1. Add sticky save bar when there are unsaved edits.
2. Split into sub-tabs/steps for long forms:
   - `Basics`, `Sports`, `Availability`, `Bio & Social`.
3. Inline validation:
   - duplicate sport guard
   - social handle format hints
   - bio max length indicator
4. Add “Reset this section” action.

Implementation targets:
- `Views/Profile/EditProfileView.swift`
- `ViewModels/ProfileViewModel.swift`

---

## 4) Feature Enhancements (Existing Features)

## 4.1 Discover and poke flow
Recommendations:
- Add intent filters: `Casual`, `Competitive`, `Learning`.
- Add skill-gap filter (`within 1 level`).
- Add undo snackbar after poke (5 seconds).
- Add limited “priority poke” per day.

Backend targets:
- `server/match.py` (`discover`, `poke`)
- `server/recommendation.py` (intent-aware scoring)

iOS targets:
- `Views/Home/DiscoverView.swift`
- `ViewModels/DiscoverViewModel.swift`

## 4.2 Meetup quality controls
Recommendations:
- Waitlist for full meetups.
- Host moderation mode: `Auto-approve` or `Request to join`.
- State badges: `New`, `Almost Full`, `Starting Soon`.
- One-tap participant reminder for hosts.

Backend targets:
- `server/meetup.py` (waitlist/join request entities + routes)

iOS targets:
- `Views/Meetups/MeetupCardView.swift`
- `Views/Meetups/MeetupDetailView.swift`
- `ViewModels/MeetupViewModel.swift`

## 4.3 Match/chat continuity
Recommendations:
- Quick actions inside chat:
  - `Schedule again`
  - `Invite to meetup`
  - `Save preferred location`
- Pin important chats and mute per chat.

Targets:
- `Views/Chat/ChatView.swift`
- `ViewModels/ChatViewModel.swift`
- `server/match.py` (chat settings/preferences if server-backed)

## 4.4 Availability and scheduling
Recommendations:
- Add presets: `Weeknights`, `Weekend mornings`, `After 6 PM`.
- Highlight conflicts while proposing sessions.
- Optional calendar conflict sync (read-only).

Targets:
- `Views/Profile/EditProfileView.swift`
- `Views/Chat/ProposalSheet.swift`
- `Utilities/AvailabilityHelper.swift`
- optional EventKit integration in iOS layer

---

## 5) New Feature Opportunities

## 5.1 Instant Play mode (highest near-term upside)
Feature:
- A mode for users available in next 2 hours.

Why:
- Strong for spontaneity and reducing planning friction.

Backend:
- Add endpoint for near-term candidate ranking (`/discover/now` style).

iOS:
- Toggle in Discover and Meetups filter strip.

## 5.2 Reliability scoring
Feature:
- Score based on attendance, acceptance rate, no-shows.

Why:
- Improves trust and reduces commitment mismatch.

Backend:
- Add feedback entities and aggregate fields on users.

iOS:
- Display compact reliability badge in Discover/Profile/Meetups.

## 5.3 Post-session feedback loop
Feature:
- Prompt after session/meetup:
  - `Did they show up?`
  - `Would play again?`

Why:
- Feeds recommendation quality and safety.

Targets:
- Backend: new feedback route/entity.
- iOS: post-session prompt surface in Chat/Meetup detail.

## 5.4 Squads / recurring groups
Feature:
- Convert successful meetup participants into recurring squads.

Why:
- Drives retention via repeat play habits.

Targets:
- Backend: squad entities, recurring schedule logic.
- iOS: squad list + squad chat entry point.

## 5.5 Trust and safety controls
Feature:
- Report/block from profile/chat/meetup.
- Visibility controls (`show me only to same sport interests`).

Targets:
- Backend: block/report endpoints and filters in discover/messaging.
- iOS: action menus in key screens.

## 5.6 Personalized re-engagement
Feature:
- Smart notifications:
  - `3 compatible players free tonight`
  - `2 meetups starting soon nearby`

Targets:
- Backend recommendation + event triggers.
- iOS notification deep links into filtered tabs.

---

## 6) Prioritized Roadmap

### Phase 1 (1-2 sprints): polish and conversion
- Discover card refinement + secondary actions
- Matches row metadata + unread indicators
- Edit Profile unsaved-state and validation
- Meetups sticky search + quick filters

### Phase 2 (2-4 sprints): quality and trust
- Waitlist + join request flows
- Reliability badge + post-session feedback
- Report/block and visibility controls

### Phase 3 (4+ sprints): growth systems
- Instant Play mode
- Squad/recurring group feature
- Personalized re-engagement notifications

---

## 7) Success Metrics

Design/UX:
- Time-to-first-action on Discover
- Pokes per active user per day
- Empty-state CTA click-through
- Profile completion rate

Feature:
- Meetup join conversion and waitlist conversion
- Match-to-first-message rate
- Session acceptance rate
- Repeat activity rate (same users within 14 days)
- 7-day and 30-day retention

Trust:
- Report resolution turnaround
- No-show rate trend
- Block/report incidence by feature surface

---

## 8) Summary
The updated UI is clearly improved. The next gains come from:
- tightening design consistency,
- making key lists more informative (not just cleaner),
- improving trust and reliability signals,
- and creating continuity features (Instant Play, recurring squads, post-session feedback).

These changes will improve both first-session conversion and long-term retention.
