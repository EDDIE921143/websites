# Ediz OS 0.3.19 — recording, voice and workspace reliability

This update fixes complete-thought capture, natural read aloud and competing audio, and adds a private manuscript reader and contextual song discovery.

| Before | After | Why |
| --- | --- | --- |
| Live recognition could replace the beginning of a long idea. | Capture and inline dictation record the entire file before final on-device transcription. Failed recordings remain recoverable. | Keep the whole thought, with no live text overlapping the recording screen. |
| Playback-only read aloud accessed the input engine and could interrupt itself. | Input processing is changed only when enabled; natural speech streams in complete word-boundary chunks. | Restore audible output without silently shortening long replies. |
| Hidden chat and call could both play a preview. | One shared preview player and one audio-session owner coordinate speech, recording and music. | Prevent competing playback and stale audio callbacks. |
| Original chapters were background context only. | Full Book provides measured pages, separate chapter starts, contents, text size and a position bookmark. | Read the private original without editing it. |
| Adding a song was only manual. | Add your own song and Add known songs provide twenty contextual suggestions, explicit saving and real catalog previews. | Make discovery useful without fabricating recordings or tempos. |
| The guide occupied much of the screen. | A compact coach expands when needed, with eight new natural recordings, longer feature explanations and a completion reward. | Keep the actual workspace available while learning. |

## Implementation

English capture uses SpeechAnalyzer/SpeechTranscriber on iOS 26 or later. Older supported systems keep the recording and explain that complete transcription requires iOS 26. Saved recordings stay inside the app until successfully transcribed or explicitly discarded/shared. Polishing preserves conditions and uncertainty, without adding deadlines or commitments.

Assistant history is sent with separate user/model roles. Bounded model recovery retains useful quota errors, requests are cancellable, and late responses cannot resurrect closed chats. Natural speech remains the default; optional device speech is not silently substituted. Calls send voice-mode instructions and use echo-controlled audio processing. Visual results require an explicit request on the current turn; greetings and ordinary conversation stay in the voice view. Calls remain turn based, with natural speech streaming and interruption handling; they are not a full-duplex Gemini Live session.

The private manuscript is excluded from Git and Vercel. The Scrivener original is untouched. Full Book pagination preserves every Unicode character. Warm linen, paper and night themes, chapter openings, edge taps, swipes, a position slider and contents make it a dedicated reading view. Music uses real available previews; Open in Spotify opens Spotify search. Embedded full Spotify Premium playback is not implemented because app registration and OAuth are required. The tutorial adds about five minutes of feature narration, plus a new welcome and goodbye, using eight prerecorded natural Aoede clips. The compact completion coach now awards an explored-lesson card. The focus timer has a quieter layered face, clear running/paused states, and a planned-duration progress ring when a duration exists. Only the complete Aoede prerecorded guide pack is installed; online calls offer the configured natural voices.

## Validation

74 JavaScript/API tests, 32 Swift Core tests and the production web build passed. Physical iPhone tests cover complete recording start/end retention, exact reader pagination, Personal assistant reply plus nonzero natural read-aloud signal, natural call output, long reply scrolling, chapter separation, song/book entry, capture/edit/undo, interactive tutorials and guide narration after microphone use. The broader physical sweep covers every workspace module and the remaining controls; final counts are recorded in the owner release report.

Audio signal tests establish that playback is generated and scheduled, not that the owner heard it. Human confirmation of call audibility, acoustic interruption and duplicate-preview behavior remains a separate check. Provider availability and free quota cannot be guaranteed.

Research and adopted native/provider tools: [tool research](TOOL-RESEARCH-0.3.19.md).

## Additional functionality

- Removed 41 Scrivener paragraph/heading/keep-with-next control tags from 15 copied manuscript sections. Existing imported records are cleaned on migration; incoming context is cleaned too. Original RTF hashes are unchanged.
- Added Work on this with AI to saved-item and creation editors across spaces: Clarify notes, Summarize, Next steps and Questions. Requests use one selected item, exclude attachments and return no automatic save actions.
- Added Copy, natural Read aloud, cancellation and retry to the record AI preview. Use these notes or Add to notes changes the editor draft; Save is still explicit. Restore original notes reverses a rewrite.
- Added an AI notes lab to the guide, with natural recorded narration, four sample tools, review/apply practice and a completion reward. The lab makes no provider request and cannot change real records.
- Reviewed native rich-text libraries and used narrowly scoped native cleanup for the actual import defect.

## Focused Assistant additions

- Song suggestion cards now offer Add to rehearsal: choose songs and a new or existing rehearsal, then review and explicitly Save. Existing setlist lines are retained and exact duplicate lines are skipped.
- Each suggested song offers an available catalog preview and Listen in Spotify. Full-song playback is handled by Spotify; embedded Premium streaming is not configured.
- Assistant now has Chats / AI notes sections. Search saved notes and open the four AI tools directly; reviewed edits still require Save.
