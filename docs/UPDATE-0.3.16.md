# Ediz OS 0.3.16 — native build 14

The signed Release app is installed on the paired iPhone. Its initial 0.3.16 build launched in Ediz's normal workspace; the final saved-chat deletion fix was installed afterward, and that relaunch was blocked by the locked device. The matching assistant backend is deployed at https://ediz-os.vercel.app. Source changes are tracked in the existing draft PR: https://github.com/EDDIE921143/websites/pull/1.

## What changed

- Capture has a dedicated recording screen: a real microphone waveform, elapsed time, visible transcript, and one Stop and keep action. The retained text stays editable before saving. The assistant's inline memo bar keeps a fixed height and preserves existing draft text.
- Each workspace has separate saved chats. Chats sits beside Information and is also available from Spaces. Conversations can be reopened and deleted individually. Deleting the open conversation switches to another saved chat or a fresh one so subsequent messages still persist. Titles use substantive context after conversation develops, rather than naming a chat Hello. Existing conversations migrate without merging separate threads.
- Search includes chat history and supports meaning-based matching against saved records and conversations. Results link to real records or reopen the matching chat. Word matching remains available when the connection fails.
- Calls start listening when opened. Requests identify the live call context and return a short spoken response plus full visual results. Song and planning lists use clean cards inside the call; the animated orb shrinks into the right corner while results are visible. Ending or pausing cancels the call's owned transcription, playback, and pending response work. Ended-call feedback is visible in the composer.
- Attachment choices open from a bottom sheet. Today uses a quieter integrated header and divided rows instead of repeated large widget panels.
- The guide uses 30 bundled natural Aoede recordings, including the first Ediz greeting, distinct course introductions, and the chapter transition after Capture. Playback, mute, replay, and progression work locally without using live speech quota. Recording mutes the guide.
- Natural is the call default. The offline backup selects the best installed speech quality and a calmer rate, with an explicit Offline backup label. Early fallback caused by an eight-second cloud timeout was removed.

## Verified in this release

- 52 unit/backend tests passed across seven files; the production web build succeeded.
- Signed iPhone Release builds and installations succeeded; all 30 guide clips are included in the installed bundle. The initial 0.3.16 normal launch succeeded. After the last deletion/voice-label fix, installation succeeded but relaunch requires the iPhone to be unlocked.
- Seven distinct physical iPhone scenarios passed: Capture persistence/completion/Undo, stable inline memo composer, chat search, separate saved-chat persistence/reopening, recorded tutorial controls/progression, call cards/end feedback, and the refined Capture recorder retaining editable text.
- Five distinct focused simulator scenarios passed: attachment picker presentation, recorded tutorial controls, clean call results/end behavior, measured audible offline speech after a rejected cloud request, and deletion of the open chat followed by a new message surviving relaunch.
- Live production requests passed call cards with separate spoken text (4.69 seconds), meaning-based chapter retrieval (1.76 seconds), and substantive chat naming (1.76 seconds). These are measured examples, not guaranteed response times.
- Earlier broad module sweeps are documented in the 0.3.15 report. They were not repeated in full for this release. Two later physical runs were obscured by a floating video/notification; corresponding guide and picker flows passed in the simulator. Screenshots containing unrelated phone content are not published.

## Current limits

Google returned daily free speech quota errors for the natural speech models, including an observed limit of 10 requests per model per day. Creating the recorded guide consumed speech capacity. Further generation attempts were stopped. The guide now works offline, but live calls currently require the installed iOS backup until provider capacity becomes available. Natural call playback is not claimed as working today.

Only the complete Aoede guide narrator is offered. Partial alternative recordings are excluded from the app. Calls retain natural voice choices for when the provider is available.

Image generation returned a provider quota error. The authenticated backend path validates real returned image data, but a native generation control is not exposed while the feature is unavailable. Photo, video, and file attachments remain separate features.

Prior GitHub full simulator runs were cancelled before completion. Current source upload triggers fresh CI; cloud CI is not confirmed green. The draft PR is not merged.

## Design references

Conversation and call presentation were informed by [ChatGPT Voice](https://help.openai.com/en/articles/20001274/) and [Pi](https://hey.pi.ai/), with native controls and Ediz OS's existing workspace themes. No design was copied one for one, and no new paid voice service or dependency was added.
