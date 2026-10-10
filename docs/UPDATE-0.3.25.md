# Ediz OS 0.3.25

## New additions

Settings → Your guide to Ediz OS → scroll to New additions. The main guide now sits near the top of Settings. New additions has a bundled natural Aoede introduction, a speaking mark, explanations and links to try Music tools, Gym and AI Notes. Gym also appears in the main guide.

CLEARANCE 19 can show original practice tablature and chord diagrams as native cards, with adjustable visual timing and copy controls. Requests to find song tabs use web lookup; uncertain sources and generated patterns must be labelled honestly. No synthetic instrument playback was added.

Assistant instructions now emphasize warm, direct answers, separate workspace roles, readable formatting and avoiding stock greetings, fake familiarity, invented context or promises of changes without a real action.

Gym Bot now returns real reviewable plan actions. Production tests verified a four-set/120-second-rest edit and a machine replacement using the complete exercise catalogue. Existing provider fallback repairs are now deployed.

Five matching Gym exercises have real Your Move video demonstrations: pec-deck fly, reverse fly, leg extension, cable pushdown and hammer curl. Other exercises retain clearly labelled still references. A streaming incompatibility was fixed by downloading the selected clip into the app cache before playback; repeat playback can work offline. Gym settings can clear downloaded demonstrations without deleting workouts. Failed saved Gym data is preserved and shown as a recovery issue instead of silently overwritten.

## Design review

| Before | After | Why |
|---|---|---|
| Stronger Gym gradient/pattern | Quieter tint and sparse lines | Keeps attention on the workout controls |
| Instrument content as plain text | Drawn string grids and chord diagrams | Makes musical positions readable |
| Guide buried in Settings | Guide near the top, New additions at its bottom | Makes walkthroughs and recent features easier to find |
| Exercise images mistaken for videos | Explicit video control or still-reference label | Shows what the control actually does |

## Verification and limits

80 JavaScript/API tests and the web build pass. Three combined simulator tests and the same three physical iPhone tests pass: guide/new additions/music cards, actual advancing video playback, and exercise search/add. Live production greeting, original tab generation, Gym set/rest edit and catalogue-backed replacement pass. Signed release installation/launch is recorded separately in the delivery report.

This was a focused sweep of assistant actions, guide discovery, music rendering, Gym demonstrations, data recovery and related layout. It is not a claim that every app button was tested. Automated audio controls do not establish human-perceived voice quality. This changes instructions and tools, not model weights. No private manuscript or credentials are uploaded. The GitHub PR remains draft and unmerged.

## Sources

Video clips: [Your Move free exercise videos and usage terms](https://ymove.app/free-exercise-videos). Still references: [free-exercise-db](https://github.com/yuhonas/free-exercise-db).

Notation options evaluated: [AlphaTab documentation](https://docs.alphatab.net/docs/introduction) and [Soundslice embed API](https://www.soundslice.com/help/en/embedding/javascript-api/38/introduction/). They were researched, not integrated; this release uses focused native drawing and visual timing.
