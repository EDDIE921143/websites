# Ediz OS 0.3.32 — Mentor Desk

Mentor Desk is an English-language workspace for Ediz as a peer tutor. Students’ learning and deadlines stay separate from his own School space.

| Before | After | Why |
| --- | --- | --- |
| No place to follow tutoring students | Student directory, subjects, class, learning journal and archive | Keep each student’s progress together |
| Session updates took a general note | Log session with optional title, German/English speech, camera and photos | Keep a useful note quickly |
| Deadlines mixed with personal schoolwork | Student-owned tests, session dates and goals in a shared calendar | Know whose deadline it is |
| AI could mix students | Student-specific context, chat history and enforced ownership of proposed changes | Keep discussions and edits within the selected student |
| New workspace used a gray, dotted presentation | Teal, notebook folds and the same workspace cards/controls as the app | Recognizable identity with consistent navigation |
| No hands-on introduction | Eight-step course including introduction and seven real practice actions, with prerecorded natural Aoede narration | Learn by using a fictional student without changing real records |

## Using Mentor Desk

Open Spaces → Mentor Desk. Add the student’s name, subjects and optional class. Open their profile and choose Log session to record what you covered and what comes next. Speak supports German by default and English from its language picker. Stop returns text for review. A photo is kept with the entry; readable text is extracted locally. The AI clarification/polishing tool proposes a reviewable note. Online verification is a separate explicit action that returns sources. Neither is an automatic save.

Session date, Their test and Learning goal belong to that student. Calendar combines scheduled items across students; the week strip jumps to a day. Enable reminders in Mentor Desk options and allow iOS notifications, then choose a lead time on the entry. Edit or delete entries from their menu, and mark a learning goal complete when done. Archive a student to keep their history while removing them from active reminders. The sparkle beside Log session opens their own assistant and Chats keeps that student’s conversations.

The guide is in Settings → Your guide → Mentor your students, in New additions, and Mentor Desk options. It uses separate practice records and does not schedule notifications. Narration is bundled and can play offline; it is not regenerated each time. The detailed lesson also explains photos, AI review, reminders, archive and Focus. CLEARANCE 19’s native and catalog accent is now red.

## Tools and boundaries

German recognition uses [Apple Speech](https://developer.apple.com/documentation/speech/sfspeechrecognizer). Photo text uses [Apple Vision](https://developer.apple.com/documentation/vision/vnrecognizetextrequest). Reminders use [local iOS notifications](https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app). [HorizonCalendar](https://github.com/airbnb/HorizonCalendar) was researched; this version uses native date controls and adds no calendar dependency. Camera, recognition and cloud AI require their corresponding permissions or connection. There is no automatic external calendar sync or student messaging.

Validation evidence is recorded in the local delivery report. Private student material, manuscript, credentials, database and local handoff are excluded from Git and deployment.
