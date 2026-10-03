# Ediz OS 0.3.17 — native build 16

## Delivered changes

| Before | After | Why |
| --- | --- | --- |
| Ordinary Gemini replies could fail with a provider schema rejection | Retry the same model in JSON mode without its rejected schema, then validate returned actions | Recover compatible replies without bypassing record validation |
| Natural audio failed and a restarted microphone tap could crash playback | New compatible natural TTS candidate; reset playback/input taps before restarting | Restore live Aoede audio and stable call playback |
| Offline voice could replace the selected natural voice automatically | Offline backup is an explicit setting, off by default | Respect the selected voice |
| Long replies opened at their bottom and list text could truncate | Open assistant answers at their beginning, wrap full item text, fade scroll edges | Keep large lists readable through their last item |
| Flat paused call circle | Layered MIT Orb material remains present when paused; motion follows activity and audio | Preserve depth without meaningless idle motion |
| Bright accents and overlapping rehearsal controls | Warm charcoal/terracotta, welcoming Today copy, separated BPM/control rows | Improve hierarchy and usable spacing |
| Voice ideas retained fillers | Gemini polishing with original/polished controls and preservation of uncertainty and user edits | Save understandable ideas without adding facts |

Calls support recognition during playback and a bundled natural Aoede “Go ahead” interruption cue. Only the cue is prerecorded; answers remain live. Actual acoustic interruption still needs owner confirmation. The tutorial retains its 30 natural recordings and now celebrates completed steps with short, reduced-motion-aware transitions.

The verified RELAX CUT project link is included in EJJ context. HSS is identified as a local concept with no verified public URL. Earlier chat memory is scoped and read-only. Greeting instructions avoid fabricated replies or unrelated song lists.

## Verification

- 60 unit/backend tests passed, including schema-rejection recovery and unsafe-action filtering.
- 31 browser scenarios and 27 Swift Core tests passed; production web and signed iPhone Release builds succeeded.
- Broad native sweep: 28 scenarios passed, five skipped, two test-fixture issues corrected and rerun successfully. Focused final checks passed five scenarios; separate 24-item long-list and call checks passed both scenarios.
- Physical iPhone Capture, playback crash recovery, and live natural Aoede output tests passed. Natural output was measured in the app; no claim of owner-confirmed audibility or acoustic interruption is made.
- Live production hello, Capture polishing, meaning-based search, and honest Slack status requests returned HTTP 200. Sample greeting/polish latency was approximately 2.1/1.0 seconds, not a guarantee.
- Build 16 was installed on the paired iPhone. Final launch status is recorded separately in the accompanying delivery report.

## Limits

The app's read-only Slack adapter is implemented, but its dedicated channel allowlist and server credential are not configured. The existing EJJ Worker token remains private to that Worker; its daily automation was not changed. The app honestly reports Slack unavailable.

Google free speech quotas can still be exhausted; the repair does not remove provider limits. Image generation remains quota-blocked and no nonworking native generation control is exposed. CI status for the final source upload must be checked separately. The GitHub PR remains a draft.

## Sources

[Orb source and MIT license](https://github.com/metasidd/Orb), [Apple voice processing](https://developer.apple.com/videos/play/wwdc2019/510/), [Gemini speech generation](https://ai.google.dev/gemini-api/docs/speech-generation), [Slack history permissions](https://docs.slack.dev/reference/methods/conversations.history/).
