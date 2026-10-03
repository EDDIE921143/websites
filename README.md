# Ediz OS 0.3.18

An owner-specific personal operating system, primarily a genuine SwiftUI iPhone app. The web companion is available at https://ediz-os.vercel.app. Both editions work locally without paid APIs, analytics or a server database.

Current update: [0.3.18 validation and limits](docs/UPDATE-0.3.18.md).

## Native iPhone edition

`ios/` contains a real SwiftUI application with no WebView or Capacitor runtime. It uses iOS TabView, NavigationStack, sheets, file pickers, sharing, Quick Look, on-device speech and AVFoundation. The iPhone 17 Pro is the primary test device. iOS 26 supplies native liquid-glass controls; older supported versions use material controls. Content remains on stable warm charcoal surfaces, with Avenir Next typography, neutral space rows and restrained identity colors. No personal images or fabricated data are included.

The floating system tab bar supports horizontal scrubbing through Today, Assistant, Capture, Search and Spaces. Capture is a real tab; contextual capture remains available as a dismissible sheet. Native swipe-back and sheet dismissal are preserved.

The local `native/Core` Swift package uses durable SQLite with WAL, foreign keys, transactions, history, recoverable capture/edit drafts and seven daily safety snapshots. Attachments and structured data are separate. Full JSON backups, readable Markdown and profile exports support migration and recovery. Daily snapshots protect recent edits; external exports are still needed for device loss.

Today uses explainable deterministic priorities. The contextual assistant handles next steps, reasons, tomorrow, waiting items, saved information and reminder drafts. It never saves a proposed reminder without review or changes canon silently. Optional OpenAI-compatible local models are disabled by default and require explicit exposure of context. No cloud API key or model download is required. The adapter has not been verified against a live LM Studio server.

Implemented modules include EJJ leads/pipeline and websites; band songs, rehearsals, practice audio and metronome; Moshia chapters, characters, creative states, timeline and plot threads; school assignments, tests, workload and weighted grade estimates; Personal tasks, appointments, ideas and notes. Native focus uses an elapsed timer with begin, pause and continue controls.

### Verified native build

GitHub Actions run https://github.com/EDDIE921143/websites/actions/runs/36847582563 compiled the app and UI tests with Xcode 26.3 on macOS 15. All 18 Swift core tests and seven XCUITests passed on an iPhone 17 Pro simulator. Tests cover capture/reload/completion/undo, edge swipe-back, sheet dismissal/draft recovery, real space destinations and creative states, assistant follow-ups and reminder preview, focus controls, and sliding across the tab bar. Actual screenshots and test evidence are archived by the workflow. An unsigned physical-iPhone Release archive also built successfully.

**Current physical-device status:** 0.3.18 was signed, installed and launched on the owner’s paired iPhone. Capture’s voice-only screen and Stop/edit behavior passed an on-device UI test; guide narration/mute/replay also passed earlier in this update. This supersedes the original signing blocker above. Human confirmation of call audio and long-form acoustic testing remain separate checks.

## Web companion

React, TypeScript, Vite, IndexedDB and a precached PWA. The 0.3.0 redesign includes humanist typography, glass controls and a draggable dock, a deliberate Today layout, actionable space shortcuts, contextual assistant conversation and gentle focus controls. The domain model and existing production origin preserve browser data.

`npm ci`, `npm run dev`. Production build: `npm run build`. Unit verification: `npm test`. Browser verification: `npm run test:e2e`. Production verification: `EDIZ_TEST_URL=https://ediz-os.vercel.app npm run test:e2e`. Install Chromium with `npx playwright install chromium` when needed.

16 web unit/database/assistant tests and ten Chromium browser workflows verify editing, capture, completion/undo, offline writes, fuzzy search, backup/restore with files, creative states, lead stages, songs/rehearsal, grades, draft recovery, short keyboard viewport, accessible switches, drag navigation, contextual assistant and focus. Layout checks cover 320/402/768/1440px. Screenshot QA covers Today, Spaces, Assistant, Focus and desktop. WebKit cannot run in this workspace because its required system libraries are unavailable.

Browser storage and native SQLite are independent. Each device has its own data. Full JSON export/restore, including attachments, is the migration route. Automatic sync is not implemented. IndexedDB transactions protect saves and history; storage persistence is requested and local daily snapshots are retained. All imports are processed locally with a preview, duplicate detection and confirmation before complete replacement. Creative entities default to POSSIBLE.

Bundled Lato font subsets are self-hosted; iOS uses its installed Avenir Next font. Uiverse-inspired controls and licenses are credited in THIRD_PARTY_NOTICES.md. No private records, local databases or imported files belong in source control.

## Source and limits

Approved source branch: https://github.com/EDDIE921143/websites/tree/ediz-os-native. Vercel hosts the static web build at the existing origin. The native build does not depend on Vercel.

Not implemented: signed native distribution, cross-device sync, reliable scheduled background notifications, authenticated third-party sync, semantic embeddings, automated continuity reasoning, secure app lock, remote backups, waveform decoding or fully normalized creative relationship editing. Website deployment information is saved metadata, not a live integration. Grade estimates are unofficial. The local assistant is a transparent rules-based helper; optional local models expand its language capabilities.

Core source: `native/Core/Sources/EdizCore`; native UI: `ios/App/App/Native`; native gesture tests: `ios/App/EdizOSUITests`. Web domain/storage: `src/core.ts`, `src/db.ts`; shell: `src/main.tsx`; design/navigation: `src/Today.tsx`, `src/Dock.tsx`, `src/primitives.tsx`, `src/style.css`; assistant: `src/assistant.ts`, `src/ConversationAssistant.tsx`.
