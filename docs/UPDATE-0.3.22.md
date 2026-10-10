# Ediz OS 0.3.22

## New and changed

- Assistant chats start a new conversation after five minutes away. Earlier conversations remain in each bot's Chats list; opening a saved chat keeps that chat selected.
- Moshia's Full Book now has a dedicated listening screen, searchable chapter picker, playback speed, voice choice, and pause/resume. A chapter is recorded on first use and reused from on-device storage. Preparing the book records missing chapters in sequence while the book is open. Changing a chapter or voice records only that chapter/voice combination again. The screen stays open at the end so Ediz can replay or choose another chapter.
- Long Read aloud replies now speak the full reply text, with formatting marks removed. Natural narration uses one Live voice path to avoid model changes between segments. If speech fails mid-chapter, the app shows Retry instead of silently advancing.
- Assistant media is saved locally with its conversation; sent images and files can be opened again. Recent attachments are included in follow-up requests. When a referenced older attachment is unavailable, the assistant asks for it again.
- School Bot uses study-specific instructions and readable math notation. Moshia Bot stays within provided manuscript context; other bots use their own directions.
- Capture clarification questions accept spoken answers. Completed-item feedback dismisses automatically. Settings offers opt-in local reminders for saved deadlines and a Moshia writing nudge. Gym appears in Spaces as under construction only.

## Limits

- Audiobook preparation needs the connected assistant and Google speech capacity. Prepared recordings play offline. The whole book is stored as reusable chapter recordings so chapter search, voice changes, and updates do not regenerate everything.
- Reminders are local scheduled notifications from saved dates and settings, not autonomous AI-generated notifications.
- Math display normalizes common notation and Markdown; it is not a full LaTeX renderer.
- The original private Scrivener manuscript and assistant connection credential stay outside Git.
