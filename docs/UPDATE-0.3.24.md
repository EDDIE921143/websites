# Ediz OS 0.3.24 — Gym editing and spoken practice

The week uses a horizontal weekday selector and shows one workout at a time. The exercise chooser now shows reference thumbnails, equipment and muscle labels, with roomier rows and separate muscle/equipment filters. Each planned exercise has its own editor section with sets, target, superset and rest controls. A visible Remove action uses a distinct confirmation button. Bindings resolve stable exercise IDs, so removing one row cannot redirect a later edit to its neighbour.

Gym Bot can propose weekday swaps, specific calendar dates, day names, exercise additions/removals/replacements and set/rest/target/superset edits. Review → Apply to my plan saves a validated change. The complete exercise ID/name catalogue is available as context. Stale IDs and unavailable exercises are rejected; edits are atomic. Existing active-workout logs and completed history stay intact. Returning from chat reloads the saved plan. The backend instructions and validation need deployment before live Gym Bot can offer these new actions.

Gym settings includes an eight-part walkthrough with hands-on practice for moving a day, choosing sets, entering a practice weight/repetition count and adjusting rest. It introduces the library, technique, custom exercises, supersets, Gym Bot review and workout history. The practice controls do not write to actual workouts. Eight natural Aoede narration recordings are bundled for offline playback, with a voice-reactive guide mark, progress, animated step changes, a welcome and goodbye. Narration can be muted or replayed; no device voice is substituted. These recordings add approximately 1.1 MB. The guide returns to the top when a step changes.

| Before | After | Why |
| --- | --- | --- |
| Plain exercise name rows | Reference thumbnails and equipment/muscle labels | Recognise the movement before opening it |
| Position-based exercise fields and hidden deletion | Stable IDs, separate exercise sections and visible removal | Preserve the right item during edits |
| Gym Bot could only describe changes | Reviewed structured changes update the saved plan | Make requested plan edits actionable |
| Text-only Gym instructions | Eight narrated lessons with practice controls | Learn the actual workout flow |

Validation: 79 JavaScript/API tests, the web build and 38 Swift core tests pass. Core checks cover stale removal IDs, weekday swaps, date restoration, atomic validation and keeping active-workout sets intact. Focused simulator tests verify exercise search/add and applying a reviewed change, including saved sets/rest after restart. Removal and persistence checks pass after using a distinct confirmation target. Tutorial spacing and final device installation are reported separately in the owner update.

Vercel deployment is pending renewed sign-in. The physical iPhone was locked during this pass, so no new on-device visual or audibility claim is made here. Natural narration files contain a complete audio stream with nonzero signal; human voice quality is separate from these checks. Private manuscripts and assistant credentials are excluded from Git and deployment.
