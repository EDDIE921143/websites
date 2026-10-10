# Ediz OS 0.3.14 · verification record

Completed on 3 October 2026 on the connected iPhone 17 Pro and Chromium. Checks used isolated test databases; normal personal records and voice preferences were preserved.

## Changes

- Navigation order is Today, Assistant, Capture, Search, Spaces.
- Natural speech streams PCM as it arrives, caches completed short replies and falls back to installed device speech when the cloud voice request fails. The microphone and speaker visuals use measured audio levels. Idle drawing stops, and voice settings use a full-height sheet with a standard voice-selection list.
- Focus changes the background color/pattern, main card and OS logo accent. Workspace chats retain their own theme.
- Rehearsal offers BPM entry with automatic number selection, bounded ± controls, tap tempo, real metronome audio and restrained beat/setlist transitions.
- Moshia has a continuity desk with the latest saved chapter, plot threads, chapter outline and a separate canon ledger. CLEARANCE 19 shows setlist readiness and rehearsal tools. Existing business pipeline, school workload/grade projection and personal focus features remain available.
- Canon, deletion and backup replacement use explicit cancel/confirm alerts. Unsaved record edits cannot start a focus session. Profile restore validates preferences, and empty backups can be restored.
- Attachment cancellation leaves the composer usable. Videos preserve audio and use four visual samples per second. Common audio formats are accepted. Ordinary chat uses the faster model; media can use the stronger model, with provider and transport fallback. Precise audio-only pitch transcription is not presented as a calibrated detector.
- Rehearsal recording playback now loads enough audio to seek, loop and change speed. Saved browser preferences are serialized and expose their durable-write state.

## Verification

| Surface | Passing coverage |
| --- | --- |
| Native core | 27 tests: storage, backup/profile validation, drafts, audio meter, priorities and invalid durations |
| Web/backend | 48 tests: database/core, assistant validation, media formats, PCM streaming/cache/retry and model routing |
| Browser | 31 workflows, including all 28 modules, persistence, imports/exports, density/focus, actual Web Audio scheduling and recording loops |
| Physical iPhone | 25 distinct scenarios across the full sweep and targeted repair runs; all 28 modules create/save/reopen, inline dictation states, one-tap typing, scoped chats, six interactive tutorials, capture dismissal, swipe-back, dock scrubbing, context, focus sessions, canon/deletion, history/import, density, voice settings, streaming speech, explicit cloud-failure fallback and the new continuity/tempo controls |

The initial device run exposed failures. They were investigated with actual screenshots and repaired, then rerun. This table describes combined verified coverage, not a single uninterrupted 25-test run. Real natural speech and the deliberately rejected cloud-voice request both produced a nonzero measured playback signal on the phone.

## Limits

This is a broad control and regression sweep, not proof that every input, permission state or hardware combination can never fail. Bluetooth/AirPlay routing and completing external iCloud share actions were not exhaustively tested. Natural speech and Gemini chat depend on network/provider quota; device speech fallback does not remove a text-model quota. Calls are conversational turns, not simultaneous bidirectional audio.

A six-second video fixture correctly identified the visible A4, C5 and E5 changes and timestamps. Blind audio-only tests gave unreliable pitch/count answers. Exact music transcription requires dedicated signal analysis and is not guaranteed by this app. Attachments total at most 2.5 MB and videos are limited to 60 seconds. Saved briefs are historical context, not continuous synchronization of every ChatGPT conversation.

## Tool research

The implementation uses [Apple Accelerate RMS metering](https://developer.apple.com/documentation/accelerate/vdsp_rmsqv), native AVAudioEngine and SwiftUI. [DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage) and [AudioKitUI](https://github.com/AudioKit/AudioKitUI) were reviewed as references; no additional audio framework was installed. Streaming and video handling follow [Google speech generation](https://ai.google.dev/gemini-api/docs/generate-content/speech-generation), [video understanding](https://ai.google.dev/gemini-api/docs/generate-content/video-understanding) and [thinking controls](https://ai.google.dev/gemini-api/docs/generate-content/thinking?hl=en).
