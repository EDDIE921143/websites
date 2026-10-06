# Ediz OS 0.3.30

| Before | After | Why |
| --- | --- | --- |
| Everyday included every space and the manuscript automatically | A Gemini context tool selects relevant IDs from a title catalogue; only selected bodies enter the answering prompt | Personal context is retrieved for the question, rather than dumped into every answer |
| Workspace filtering depended on the app | API filters records, briefs, memories and actions by workspace | Moshia cannot receive business or Gym context through a mixed request |
| Greeting requests still carried saved content | Greetings and simple time questions skip context retrieval, including on the native client | Ordinary conversation needs no personal record review |
| Large workspace bundles went directly to the answering model | Large bundles use the same bounded retrieval tool | Reduce unrelated content and large prompts |
| Search had no speech entry | Microphone, reactive listening bars and editable transcription next to the existing semantic search | Describe a memory aloud, then search by meaning |
| Gym used a generic Spaces row | Dedicated training card at the top of Spaces with today's plan and recovery state | Give training its own visual identity |
| Chat opened with a context dump card | Quiet workspace identity and a clear explanation of its context boundary | Keep the opening useful and uncluttered |
| Today had no direct assistant entry | Talk it through opens Everyday from the welcome area | A short route from the day to a conversation |
| Reminders used identical notification content | Workspace subtitle, thread and matching artwork attachment; Gym has a custom three-tone rest alert | Make reminder origin recognizable |

Notification artwork is an attachment; iOS retains the Ediz OS application icon. Custom sounds remain subject to system notification settings.

Retrieval failures release no saved records. The assistant is instructed to ask when personal facts are missing. Search still falls back to saved local results if the cloud search fails. All proposed record/plan changes retain the existing review step.

Verification: JavaScript/API tests and the web build pass; 41 native core tests pass. Three initial simulator checks passed for separate chats/typing, reopening a saved chat from Search, and the new Search/Gym entry. The final Gym-first layout passed on both simulator and physical iPhone. The first physical test missed its Search tap; an explicit coordinate tap passed. Live production checks returned 200, retrieved exactly one requested Moshia note in both Moshia and Everyday, excluded the test business secret, skipped retrieval for a greeting, and ranked the correct note in semantic search. Early live retrieval checks did not find their test fact and are not counted as passes; the final checks include the provider tool's selected-record count.

Custom notification artwork and the one-second bundled Gym chime are implemented, but audible background delivery has not been manually confirmed. Search microphone placement is verified on iPhone; spoken-query transcription still needs a human speech check. Release build 29 is signed; install and launch are tracked in the user-facing update report. The GitHub PR remains draft and unmerged.
