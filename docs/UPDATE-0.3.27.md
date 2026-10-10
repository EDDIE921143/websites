# Ediz OS 0.3.27 — Request recovery and offline audiobook

## Request reliability

The server now detects empty, cut-off, malformed and unusable model replies inside its existing fallback loop instead of failing after an HTTP 200. A brief provider overload gets one short retry before switching models. Provider content blocks remain explicit and are not retried through another model.

The native client makes at most one recovery retry for brief connection loss, temporary server errors, a short Retry-After quota response or an unreadable response. Authentication failures, invalid requests and cancellation do not retry. Suggestions are still reviewed before saving; the retry returns one reply to the original pending message.

The browser timeout now covers the server’s recovery window and one bounded retry handles temporary error pages. Broken music catalogue entries and malformed grounding metadata cannot crash normal response processing. Optional allowlisted Slack channels load together instead of adding their timeouts one after another.

## Download once, play offline

Moshia → Full Book → Contents → Audiobook now has a narrator selection, Download audiobook, and Play full book immediately below. Full-book playback is enabled when every current chapter is downloaded. Existing valid chapter recordings are reused. Audio lives in application support, not disposable network cache.

Preparation uses 700-character segments instead of the old 260-character live segments, with two chapters prepared concurrently. Finished segments survive interruptions, so resume skips them. Each complete chapter is joined locally into one AAC recording; intermediate segments are removed after a successful join. Changing chapter text or narrator invalidates only the matching recording.

The dedicated player shows actual total downloaded duration, elapsed position and a seek slider across chapter boundaries. Pause survives seeking into another chapter. Narrators must be downloaded before the player switches to them. Book narrator choice is separate from chat voice. Playback uses local recordings without requesting the AI again.

| Before | After | Why |
|---|---|---|
| Many small serial preparation requests | Larger segments and two chapters in flight | Reduces connection overhead and sequential waiting |
| A failed chapter lost all unfinished progress | Successful segments are retained until the chapter is joined | Resuming avoids repeating finished generation |
| Listen could start while most chapters were missing | Download status, then Play full book | Makes offline availability explicit |
| Progress showed chapter count | Real total time and cross-chapter seeking | Behaves like an audio player |
| Artwork pushed lower controls down | Smaller responsive artwork and distinct control identifiers | Improves spacing and accessibility |

## Verification and limits

89 JavaScript/API tests, 39 Swift core tests and the web build pass. A real two-chapter synthetic sample downloaded on the paired iPhone. The app then relaunched without access to the assistant credential and played the sample with a full duration and working pause/seek. A separate physical test joins prerecorded segments and verifies that cross-chapter seeking preserves pause. Initial accessibility failure was diagnosed from the actual phone hierarchy and corrected. These checks use invented/public samples, not the private manuscript.

Live production checks verify correction handling, semantic recall and malformed-request rejection. Signed release installation and launch are recorded in the delivery report. Source remains in the existing draft PR, unmerged; private manuscripts and credentials are excluded.

First-time narration still depends on provider availability and book length; there is no measured whole-manuscript speed comparison. Keep the book open during preparation. Offline playback is immediate once that voice and current text are downloaded. Genuine outages, exhausted quota and invalid credentials remain visible; recovery does not disguise them or silently substitute another voice. Audio quality was not evaluated by a human in this audit.
