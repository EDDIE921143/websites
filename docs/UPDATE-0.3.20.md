# Ediz OS 0.3.20 — tutorial refresh

Prepared locally, checked in an iOS simulator, and uploaded to the existing draft GitHub PR after Ediz approved the generated narration assets. The signed 0.3.20 Release was installed and launched on the connected iPhone. Its first focused device run passed all six existing lessons and spoken-guide playback; two navigation assertions needed more reliable test scrolling and were repaired in 0.3.21.

| Before | After | Why |
| --- | --- | --- |
| Updated lesson text still used older shared voice clips for individual steps. | Each of eight courses has its own intro, full explanation, action guidance and ending. | Spoken instructions now follow the current lesson and its actual controls. |
| Later lessons used the same short presentation. | Course accents, symbols, progress movement, target highlights and small step celebrations cover all lessons. | Make progress and the next action easier to understand. |
| Reading and rehearsal were described but had no dedicated walkthrough. | New hands-on Full Book and rehearsal lessons use sample chapters and songs. | Learn page turns, contents, tempo entry and metronome controls by using them. |
| Reader practice shared appearance and position preferences with normal reading. | Practice size, paper and reading position stay local to the practice session. | Trying a tutorial does not change real reader preferences. |
| Starting the metronome could compete with guide narration. | Narration pauses while the beat plays and resumes after stopping. | Let the chosen sound finish its job. |
| The AI notes lab ignored the guide’s voice preference. | It respects spoken guidance, offers mute/replay and has explanations for the four tools plus a distinct ending. | Keep tutorial voice behavior consistent. |
| Two coaches were exposed while rehearsal presented its own screen. | The underlying practice coach is hidden while the rehearsal coach is active. | Avoid duplicate controls and confusing completion actions. |

The guide includes Capture a thought, Create a chapter, Explore a chat, Find your work, Change the look, Focus on a space, Read your book, Set up a rehearsal and the AI notes lab. The eight courses contain 41 guided steps, plus the lab’s four tools. Narration uses fixed generated Aoede recordings rather than a device voice or a live request. Lessons can be muted or replayed offline; animations respect Reduce Motion.

Validation: 74 API/JavaScript tests and 32 Swift Core tests passed, and the production web build passed. The original six walkthroughs passed their simulator flow test. The new reading/rehearsal flow, reader navigation, AI lab, density changes and capture save/undo were also exercised. Final audio pack and simulator regression results are appended below.

This sweep does not establish how the audio sounds to a listener or that every possible input in every app function has been tested. Later device testing and installation status are recorded in `UPDATE-0.3.21.md`.

Audio validation: all 68 current recordings decoded successfully and their cached script hashes match the current narration. Total recorded duration is approximately 24 minutes across the courses and notes lab. Existing successful clips were reused; failed long generation requests were split into shorter pieces and assembled into complete recordings.

Final simulator run passed all selected checks: workspace module creation, reading and rehearsal lessons, natural-guide measured signal, mute, replay and advancing through real controls. The broader runs also passed all six original lessons, AI notes lab, density changes, page navigation and capture persistence/undo. A module assertion was repaired to scroll to its existing canon warning when the keyboard obscures it.
