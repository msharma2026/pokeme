# PokeMe Design and Feature Recommendations (March 2, 2026)

## Goal
Provide a focused set of design upgrades and feature improvements to make the app feel more premium, easier to scan, and more useful day-to-day.

## Design Changes

### 1) Build a strong visual system (not screen-by-screen styling)
- Create a shared design language with:
  - 1 primary gradient family (warm athletic palette)
  - 1 neutral surface system for cards/backgrounds
  - 3 text tiers (title/body/meta)
  - consistent corner radius and spacing scale
- Why: current screens mix multiple styles (minimal vs heavy gradient), causing inconsistent polish.

### 2) Redesign bottom tab bar to increase clarity
- Keep icon style and weight consistent.
- Add subtle active-tab indicator line or glow (not only orange text).
- Increase inactive-label contrast slightly for readability.
- Add optional red badges for unseen activity (pokes, unread chats).

### 3) Improve Meetups sport-picker grid hierarchy
- Current issue: all sports look equal in priority and card depth is flat.
- Improve by:
  - adding category headers (Popular, Racket, Team, Fitness)
  - using light sport-tinted backgrounds for each tile
  - adding micro-meta under sport name (`43 active this week`)
- Add a search bar at top (`Search sport or meetup`).

### 4) Upgrade Discover card information architecture
- Current card is visually large but decision information is low in hierarchy.
- Redesign order:
  1. Header row: name, year, reliability badge
  2. Compatibility strip: % + 1-2 short reasons
  3. Shared sports chips
  4. Availability (condensed)
  5. Primary CTA (`Poke`) + secondary (`View profile`)
- Make the card less image-dominant and more action-dominant.

### 5) Improve empty states across app
- Empty states should provide a next action, not only a message.
- Example for Pokes:
  - Primary button: `Go to Discover`
  - Secondary: `Complete profile for better matches`
- Add subtle illustration consistency (same icon style, same card style).

### 6) Profile page cleanup
- Make profile sections collapsible: Sports, Availability, About, Socials.
- Replace mixed gradients with section accent colors only in headers.
- Add profile completeness ring near avatar (`82% complete`).
- Move settings to top-right icon-only; keep `Edit profile` as sticky action.

### 7) Matches list visual upgrade
- Add segmented control at top: `1-on-1` | `Group`.
- In each row show:
  - unread dot
  - last message preview
  - relative time (`2m`, `1h`, `Yesterday`)
- Different avatar style for group chat vs direct match.

### 8) Typography and spacing adjustments
- Increase title-to-content vertical spacing on list pages.
- Use one display font weight pattern for all top headers.
- Reduce text crowding in cards by enforcing min 8-12 pt vertical rhythm.

### 9) Motion strategy
- Keep only meaningful animations:
  - page entrance fade/slide
  - CTA press feedback
  - badge count changes
- Reduce continuous looping animations that compete for attention.

### 10) Accessibility-first pass
- Ensure color alone is never the only state signal.
- Increase contrast for secondary labels.
- Support dynamic type without clipping in cards and tab labels.
- Add VoiceOver labels for all critical action buttons.

## Feature Improvements

### 1) Instant Play mode (high impact)
- New toggle in Discover/Meetups: `Play in next 2 hours`.
- Prioritize users and meetups with near-term availability overlap.
- Great for spontaneous users and faster activation.

### 2) Better meetup quality controls
- Add host tools:
  - waitlist when full
  - auto-approve settings (`auto-join` vs `request to join`)
  - cancellation reason and participant notification
- Add meetup status tags: `New`, `Almost full`, `Starting soon`.

### 3) Session reliability and attendance
- After sessions/meetups, quick prompt:
  - `Showed up?` yes/no
  - optional quick vibe rating
- Aggregate into lightweight reliability score shown on profiles.

### 4) Post-match continuity tools
- Add quick actions in chat:
  - `Schedule again`
  - `Invite to meetup`
  - `Pin preferred location`
- Helps convert one-time match to repeat activity.

### 5) Smarter recommendations
- Add discover explanation tags:
  - `Same sport level`
  - `Overlapping evenings`
  - `Lives/plays nearby`
- Let users tune intent: `Casual`, `Competitive`, `Learning`.

### 6) Improved availability UX
- Add presets:
  - `Weeknights`
  - `Weekend mornings`
  - `After class`
- Add conflict highlighting when proposing session times.

### 7) Strong trust and safety essentials
- Add report/block directly from profile, chat, meetup detail.
- Add visibility controls:
  - hide profile from discover
  - only show to same sport interests
- Add optional verification badges (school email, phone).

### 8) Better notifications and re-engagement
- Smart notifications instead of generic:
  - `3 new volleyball meetups tonight`
  - `You have 2 strong matches with overlapping time`
- Add deep links to specific screen/filter.

### 9) Group-first social features
- Add `Create squad` from a meetup or group chat.
- Squad can have recurring times and reusable member list.
- Helps retention for users who prefer group play over 1:1.

### 10) User onboarding improvements
- New onboarding checklist:
  - add 2+ sports
  - set availability
  - upload photo
- Gate discover quality until minimum profile quality threshold.

## Suggested Prioritization

### Next 2 weeks
- Discover card hierarchy redesign
- Empty-state CTA redesign
- Matches list unread/preview improvements
- Tab bar consistency pass

### Next 4-6 weeks
- Instant Play mode
- Meetup waitlist + status tags
- Reliability/attendance prompts
- Recommendation explanation tags

### Next 6-10 weeks
- Squad feature
- Trust/safety full rollout
- Verification badges and profile visibility controls

## Success Metrics
- `Discover -> Poke` conversion rate
- `Poke -> Match` conversion rate
- `Match -> First message` rate
- `Meetup join` rate and fill rate
- 7-day retention and 30-day retention
- % users with completed profile above threshold
