# Ediz OS 0.3.19: tools selected for working flows

Research checked against primary documentation on 4 October 2026. Changes use the existing SwiftUI app and Gemini connection.

| Tool | Decision | Concrete use |
|---|---|---|
| Apple SpeechAnalyzer and SpeechTranscriber | Implemented on iOS 26+ | Record the entire thought, transcribe the completed audio file with final results, preserve failed recordings for retry. Physical test checks beginning and ending of a long recording. |
| AVAudioRecorder and AudioMeter | Implemented | Real microphone levels drive Capture's waveform; text appears after Stop. |
| AVAudioSession owner coordination | Implemented | Replacing speech, recording, preview or rehearsal playback stops the previous owner. Call and chat use one preview player. |
| Gemini multi-turn contents | Implemented | Previous messages retain user/model roles, alongside scoped saved context. Requests are bounded and cancellable. |
| Gemini natural speech | Improved | Natural voice remains selected; read-aloud uses smaller chunks without dropping the end of a long reply. A slower recovery path gets enough time. |
| TextKit pagination and SwiftUI page transitions | Implemented | Moshia's private original manuscript opens as measured pages. Each chapter starts a new page. Font controls, contents and a bookmark are local. |
| Apple music catalog previews | Implemented | Real catalog previews for requested tracks and contextual song suggestions; one shared audio player. |
| Spotify iOS SDK | Deferred pending app registration | Premium alone does not supply a developer client ID or OAuth connection. Current cards open the real track search in Spotify. Full Spotify playback is not claimed inside Ediz OS. |
| Additional animation libraries | Not needed for these flows | Native transitions, waveform movement, thinking state, completion feedback and page movement follow actual actions. |

Sources:
- Apple SpeechAnalyzer: https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app
- Gemini conversation history: https://ai.google.dev/gemini-api/docs/text-generation
- Gemini voice interruption and playback: https://ai.google.dev/gemini-api/docs/live-api/capabilities
- Spotify iOS SDK requirements: https://developer.spotify.com/documentation/ios/getting-started
- Spotify app lifecycle: https://developer.spotify.com/documentation/ios/concepts/application-lifecycle
- Spotify SDK source: https://github.com/spotify/ios-sdk

Privacy: the original manuscript stays outside Git and Vercel. Reader tests use synthetic Unicode text; diagnostic speech tests use recorded tutorial audio. User data is not replaced by test fixtures.

## Manuscript cleanup and record AI tools

Scrivener can expose internal paragraph-style tags in copied text. The source RTF files are retained unchanged; a narrowly scoped Foundation regular expression removes only Scrivener paragraph, heading and keep-with-next tags from the app copy. Core tests preserve normal prose, Unicode, paragraph breaks and unrelated placeholders.

Reviewed [Textual](https://github.com/gonzalezreal/textual), a native SwiftUI attributed-text renderer, and [enriched-markdown](https://github.com/software-mansion/enriched-markdown). They do not repair imported Scrivener control tags. This update keeps the existing native renderer and adds explicit record-scoped Gemini operations rather than an extra agent framework. The four operations have no save actions, cards or web search; their output is reviewed in a draft and remains reversible before Save.
