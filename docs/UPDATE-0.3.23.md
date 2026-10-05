# Ediz OS 0.3.23 — Gym and assistant refinement

Gym is available through Spaces only. Its assistant stays inside Gym and receives the saved training plan and completed exercise details. Ediz’s four-day machine-focused plan is the default, including the confirmed incline dumbbell curl. The initial three-set count and 90-second rest are editable placeholders, not supplied training prescriptions. Weekday placement can be adjusted by editing each day.

Every day has Add exercise. The library first shows machine-focused favourites; text search reaches 902 entries including named plan exercises and the public source catalogue. The bundled JSON is about 0.8 MB. Photos load on demand from a pinned source revision; unfamiliar machine variants retain an honest placeholder rather than an unrelated illustration. Muscle and equipment filters, technique instructions, paired reference photos and custom exercises are included. AI description search ranks actual catalogue IDs and cannot silently modify the plan.

Workouts have expandable cards, kg/reps or cardio minutes/km, editable rest times, superset group labels, previous completed sets, elapsed time, completed-set counts and lifted volume. Set fields save while typing, including the final repetition before tapping Complete. Timers use persisted timestamps and survive locking/restarting. Finish saves history and a summary. Optional rest notifications use iOS delivery and sound settings; foreground notification handling is included. Superset labels group movements; they do not automatically alternate exercises. Calories are not presented as measured data.

CLEARANCE 19 has no Spotify links. Apple previews play inside the app for up to 30 seconds, then stop and can replay. Reply headings, emphasis, bullets and tables are rendered; fenced guitar tabs stay aligned in a horizontally scrollable monospace block. The bot is directed to give tuning/beat labels, original practice patterns and uncertainty rather than invented verified transcriptions. Uploaded notation photos remain viewable as attachments.

Typed and local assistant requests are cancelled on background/disappearance. The provider fetch aborts when the client disconnects. Chat-title generation and known-song preview requests also cancel on background. Calls retain their voice-specific instructions and explicit-only visual results. Capture has a short, automatically dismissed destination confirmation after saving.

This release also includes the previously prepared 0.3.22 changes: pinned natural speech across long replies, persistent attachments, saved audiobook recordings, an audiobook listening screen and five-minute idle chat rotation. The compact audiobook player is hidden while the listening screen is open; its narrator control has a unique accessibility label.

## Design review

| Before | After | Why |
| --- | --- | --- |
| Gym was locked | Editable week and expandable workout cards | Make the space usable with Ediz’s actual plan |
| Last numeric value could remain uncommitted | Values save with each keystroke | Completing a set preserves the last rep entry |
| Keyboard and tab bar competed with workout fields | Keyboard dismisses on set completion; tab bar hides during a workout | Keep the active exercise visible |
| Spotify links opened another app | In-app Apple preview with a 30-second limit | Keep listening in Ediz OS |
| Raw heading/emphasis markers and proportional tabs | Block Markdown and monospace notation | Make music instructions readable |
| Capture closed without a clear destination | Short saved-to-space confirmation | Show where the thought went without requiring dismissal |

## Validation

- 77 JavaScript/API tests and the production web build passed.
- 36 Swift core tests passed, including elapsed/rest deadlines, JSON restoration, completed-set volume and workout history.
- Simulator checks passed for rich formatting and, after fixing the uncommitted-repetition bug, workout logging/restart/finish/history.
- Three focused iPhone tests passed: workout persistence, rich reply/tablature layout and audiobook playback controls. These verify controls, not human audibility or natural voice quality.
- Final release installation, final Gym UI refinement and deployment status are recorded in the owner report.

## Resources and limits

The public-domain exercise catalogue and reference photos come from [Free Exercise DB](https://github.com/yuhonas/free-exercise-db). The exercise/workout/rest patterns were informed by [Lyfta’s official usage guide](https://www.lyfta.app/usage). Rest alerts use [Apple local notification delivery](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app). No subscription, additional paid voice service or new fitness backend was introduced.

Gym data is stored with the local preferences and included in the app’s JSON backup. Remote exercise photos, AI description search and connected speech need connectivity. Rest-alert delivery while locked is implemented but was not manually heard during this check; iPhone notification permission, Focus and sound settings apply. Images are reference frames, not videos. The library is broad, not a claim to cover every manufacturer’s machine. AI notation is not a guaranteed transcription of a commercial recording. The private manuscript and connection credentials are excluded from Git and Vercel.
