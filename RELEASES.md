# Ediz OS 0.3.4

- Native controls use interactive system glass on iOS 26, with solid surfaces for reduced transparency and clearer disabled states.
- Rehearsal provides a selectable setlist, live beat indicator and reachable audio controls; song changes apply the saved tempo.
- Setlist order remains stable across database reloads.
- Web rehearsal supports horizontal song swipes and the same compact working layout.
- Sharper heading typography and accurate system health version.

# Ediz OS 0.3.3

- Attachments store portable binary buffers, retaining compatibility with existing files and backups.

- Preference choices apply immediately and write in sequence, so rapid changes keep both density and workspace focus.
- Visible density controls and a dedicated focus picker; Today shows the active workspace focus.
- Today has a personal greeting, calendar anchor, and grouped work surface. Named space shortcuts open the correct area.
- Web metronome starts and resumes audio in the tap gesture, schedules clicks on the audio clock, follows song tempo, and reports failures instead of pretending to play.
- Native metronome loops actual PCM audio using AVAudioEngine. Both versions stop their audio on exit.
- Native density changes row spacing; native Today gets the same focus controls and calendar hierarchy.

# Ediz OS 0.3.2

- Module additions now open typed editors: chapter, plot thread, location, research, idea, lead, song, homework and other entities. Quick Capture remains separate.
- Each creation form has its own durable draft and relevant fields. Moshia material begins as POSSIBLE, with explicit confirmation before adding canon.
- Moshia collections show thread development, location context, research sources and ideas.
- The web dock lens tracks the finger continuously without React rendering on each pointer movement. Navigation commits on release.
- Native dock scrubbing commits on release; native editors use SwiftUI forms and system glass controls.
- Lighter glass controls replace the previous heavy sheen. No paid service or user data migration required.

# Ediz OS 0.3.1

- Stable task rows, fewer scrolling blur surfaces, and compositor-only completion and focus motion.
- Persistent app chrome with one momentum-scrolling work surface.
- Each destination restores its scroll position and module selection. Assistant conversations remain intact across tab changes.
- Settings and imports have a clear return action; search no longer forces the keyboard open on arrival.
- Two additional browser checks cover navigation continuity, long lists, and stationary chrome.
- Native iPhone release remains the tested SwiftUI 0.3.0 build; physical installation still requires Apple signing.

# 0.3.0

A new warm-black design with humanist typography, glass lettering, neutral space rows, useful glass shortcuts and draggable bottom navigation. Chat replies use glass bubbles; tasks settle away with a short completion animation. Phone spacing is compact and the chat composer stays near the dock. Today gives one clear starting point and room to continue. Assistant supports contextual follow-ups, saved information, tomorrow and reminder previews. Focus begins gently, counts elapsed time and can pause and resume.

The genuine SwiftUI iPhone app replaces the old Capacitor shell. Its SQLite core, native gestures, glass controls, capture, modules, assistant and focus passed 18 core tests and seven iPhone 17 Pro UI tests. An unsigned device Release archive is built; Apple signing is required before installation.

The updated web companion preserves the existing origin and data format. Pictures, purple space colors, repeated arrows and thin dividers remain removed. Licensed Uiverse-derived inputs, completion controls and switches retain accessible behavior. Local-first backups and offline core remain available without paid services.

# 0.2.0

Rebuilt the interface for iPhone: black canvas, solid groups without hairline dividers, a floating dock and compact sheets. Removed decorative artwork in favor of neutral space identifiers and distinct restrained accents. Adapted credited Uiverse controls with accessible behavior. Added capture draft recovery, Home Screen installation guidance, Apple launch/icon assets and a branded Capacitor iOS project. Existing IndexedDB records and backups retain their format and production origin.

# 0.1.0

A calm, local-first home for Ediz’s work, music, writing, school, and everyday life. Includes an explainable Today view, fast capture, five built-in spaces, offline access, installable app assets, and portable backups.

## 0.3.5
- Workspace focus now shapes Continue, space shortcuts, and meaningful updates as well as priorities. Urgent school deadlines remain protected.
- Compact density affects settings, songs, chapters, timeline, agenda, and workspace lists. Preference updates are protected against stale initial loads.
- Local model connection testing and model discovery, with honest LAN/browser errors and a useful on-device fallback.
- Fixed unsaved-edit dismissal, explicit canon confirmation, safe record moves, import ID conflicts, atomic attachment saves, deletion history, and stable collection ordering.
- Removed the empty Start focus action and misleading lead completion checkbox. Grade projections stay within the selected subject.

## 0.3.6 · Today workspace focus
- Choosing a workspace replaces Today with a dedicated workspace surface, its own module links, creation action, next steps and continuation.
- Other workspace choices are hidden until All spaces is selected. Work from other spaces is hidden from the focused Today surface.
- Removed the large “Today.” heading; retained the rest of the application’s working layouts.
