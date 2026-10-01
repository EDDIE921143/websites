# Ediz OS

Live web edition: 0.2.0. Native edition: 0.3.0 development, not yet built or distributed.

Production: https://ediz-os.vercel.app

A private, phone-first personal operating system. React, TypeScript, Vite, IndexedDB, and a precached PWA. No account, telemetry, server database, or paid API is required by the application.

## Development

`npm ci`, then `npm run dev`. Production: `npm run build`. Verification: `npm test` and `npm run test:e2e`. Production browser verification: `EDIZ_TEST_URL=https://ediz-os.vercel.app npm run test:e2e` (install Chromium with `npx playwright install chromium`).

## Ownership and durability

The production origin owns the IndexedDB database. Each browser/device has independent data. The source repository contains no personal records. IndexedDB transactions keep entity updates and history together. Browser storage persistence is requested; daily local snapshots are supplementary protection, not external backups. Full JSON backups include base64 attachments, records, settings, and history. Markdown and profile exports provide additional portability. Complete restore is explicitly confirmed and performed transactionally after validating and decoding the backup.

The five built-in spaces do not contain fabricated clients, homework, or fiction canon. New creative records default to POSSIBLE. Canon changes are made explicitly in the editor. CSV, JSON, Markdown and ICS imports are previewed locally with duplicate detection.

## Release scope

Today priority ranking, deterministic capture, browser voice capture where supported, cross-space fuzzy search, command palette, focus, evening/weekly reviews, history, lead pipeline, website metadata, songs, audio looping and pitch-preserving playback, rehearsal mode/metronome, chapter index, creative states, timeline filtering, school workload, weighted grade projections, tasks/notes/ideas, attachments, backups, dark mode and offline core are implemented.

Optional localhost OpenAI-compatible suggestions are isolated in `src/ai.ts`, disabled by default, and never mutate records. HTTPS/mixed-content and model-server CORS restrictions vary by browser. No model or embedding package is automatically downloaded.

Not implemented in this release: cross-device sync, scheduled background iOS notifications, automatic authenticated GitHub/Vercel/calendar sync, semantic embeddings, automated continuity reasoning, signed native distribution, multiuser authentication, secure app lock, automatic remote backups, waveform decoding, or fully normalized creative relationship editing. Website deployment status is manually recorded metadata. Grade calculations are estimates, not official results. Voice capture availability depends on browser/device support and their speech service.

## Layout

- `src/core.ts`: domain types, parsing, search and explainable priority rules.
- `src/db.ts`: structured IndexedDB stores, transactions, import/export, attachments, snapshots.
- `src/main.tsx`: adaptive app shell and page composition.
- `src/components.tsx`: mobile sheets, editing, focus, rehearsal, audio, assistant and health.
- `src/modules.tsx`: specialized space surfaces.
- `src/primitives.tsx`, `src/style.css`: shared visual system.

Vercel uses the static `dist` output. Service workers are available in production and preview builds, not development. Installing on iPhone: Safari → Share → Add to Home Screen.

## Native iPhone application — in development

The primary layout targets the iPhone 17 Pro’s 402×874 point viewport, with safe-area insets, subtly translucent bottom navigation, compact capture sheets, black surfaces and neutral space identifiers. Appearance remains configurable. Uiverse-derived controls are credited in THIRD_PARTY_NOTICES.md.

The Home Screen version is an installable PWA with a 180px Apple icon and a targeted startup image. Settings includes installation instructions and detects standalone mode. The OS requires the owner to approve adding the icon.

`ios/` now contains a genuine SwiftUI application, using native TabView, NavigationStack, forms, sheets, file picker, Quick Look and sharing. It uses the local `EdizCore` Swift package and durable SQLite storage, with no WebView or Capacitor runtime. Its own Today layout, actionable Spaces index, capture, search, editors, domain modules, review/history, focus, audio practice and rehearsal mode are implemented in source. Audio uses AVFoundation; speech explicitly requires on-device recognition. Native and web storage are independent; full JSON export/restore is the migration route, including files and creative states.

Native verification completed here: Swift 6.1.2 compiled the core on Linux and passed 14 SQLite/domain/import tests. Native SwiftUI sources passed syntax parsing; Xcode project references, scheme and Info.plist were validated. This does **not** establish an iOS build or functioning interface. Four XCUITest workflows are prepared for capture/persistence/undo, swipe-back, swipe dismissal/draft recovery and module navigation. They have not run. The GitHub Actions macOS workflow is prepared but not published or executed, pending authorization for the available public source branch. No personal data is included.

A signed iPhone install still requires Apple signing access and an appropriate distribution path. This Linux environment has no Xcode or Apple signing identity. A simulator build will not be advertised as an installable iPhone app. No membership, paid service or hosting upgrade has been purchased. The existing production web app remains available at its existing origin, preserving its browser data.

## Verification — 2026-10-01

13 unit/database tests plus eight Chromium integration workflows cover capture/edit/completion/undo, search, offline writes and app icons, restore with attachments, creative states, lead stages, songs/rehearsal, grades, installation help, keyboard switch interaction, short viewport and capture draft recovery. Layouts are checked at 320/402/768/1440px and screenshot-reviewed with simulated top/bottom safe areas. Physical iPhone testing has not been performed. WebKit was downloaded but could not launch because required system libraries are unavailable and installing them requires root credentials not present in this workspace.

GitHub repository creation remains blocked: both GraphQL and REST returned `Resource not accessible by integration`, including after explicit repository-scope device authorization. Source remains committed in the local Git repository and included in the source archive.
