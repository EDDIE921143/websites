# Ediz OS 0.3.18 — verified changes and limits

The signed release is installed and launched on the owner’s iPhone. The assistant backend is deployed at https://ediz-os.vercel.app. Source remains on the existing draft PR; this does not merge it.

| Before | After | Why |
| --- | --- | --- |
| Live words could grow over recording controls | Voice-only Capture with microphone-driven soft layers and listening label; text appears after Stop | Stable recording layout regardless of thought length |
| A timestamp revision could duplicate a growing hypothesis | A growing or identical hypothesis replaces the current partial | Preserve corrections without appending a sentence twice |
| Stale or unsolicited panels in calls | No result while a new question is pending; explicit-result gating; Back to voice control | Results appear in response to a relevant request |
| Large lists inside one tall rounded card | Long lists flow as separate rows with vertical viewport breathing room | Reduce awkward clipped card edges |
| Recorded narration through streaming engine path could produce no output | Recorded guide clips use AVAudioPlayer; replay, mute and Capture return verified | Reliable playback of local recorded natural audio |
| Replies lacked useful actions | Copy, natural Read aloud and Stop below typed replies | Reuse and listen to the actual answer |

Capture retains completed recognition windows and renews recognition while its microphone stream continues. Polishing removes filler while preserving meaning and uncertainty. The original remains available. Thirty Swift Core tests passed, including preservation, partial corrections and growing-hypothesis duplication regression. This is not proof that every possible noisy or hours-long recording has been tested.

The private Scrivener original was read and copied into background-only Moshia context: 15 sections, Prologue plus 14 chapters. Source hashes were unchanged. The copied reference is read-only, absent from the front chapter list, excluded from Git and Vercel, and bundled only in the owner’s locally signed app. Authorized assistant requests may send those references to Gemini. No manuscript prose is in this report.

Direct CLEARANCE 19 play requests can resolve an actual Apple catalog preview. The deployed Seven Nation Army request returned the correct White Stripes track and a trusted preview URL. Remote AVPlayer playback can start before duration metadata arrives. Full-song streaming, MIDI synthesis and sheet-music playback are not claimed; actual phone preview audibility remains to be confirmed.

Normal assistant requests use JSON mode without the full rejected schema. Special-mode schema retry, model failures, card gating, readonly reference edits, music requests and Live audio recovery have tests. Natural audio can recover from exhausted TTS quota through Gemini Live using the selected natural voice. Provider quotas still apply. This recovery reads replies; it is not yet a complete bidirectional Gemini Live call.

Guide courses now have six expanded introductions plus 21 interactive actions, 27 steps total. The welcome uses Ediz. All six expanded introductions are recorded in natural Aoede audio. Guide narration can replay and resumes after Capture without permanent muting. Chat arrival, thinking dots, guide celebrations and refresh feedback use real state and respect Reduce Motion.

Verification: 66 JS/backend unit tests; web production build; 30 Swift Core tests; signed Release build; three simulator UI tests for long list, call results and guide return; physical natural-guide/mute/replay test; final physical voice-only Capture test. All these listed checks passed. The simulator list/call checks preceded the final small call-shading and long-card styling changes, which compiled in the Release. A physical short Live reply test reached the natural voice state but failed a late speaking-status assertion; its corrected timing assertion has not been rerun. Human audio confirmation and an uninterrupted long speech sample remain needed. No claim is made that every button was freshly verified in this release.

Read-only Slack integration, image generation, full duplex Live calls, expanded offline semantic indexing, and sheet-music interpretation remain separate work. No remote monitoring service or paid subscription was activated.
