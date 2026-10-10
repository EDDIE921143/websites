# Ediz OS 0.3.26 — Follow-up audit

Concrete fixes:

- Invalid request modes return a readable 400 error instead of reaching a string-method crash.
- Greetings cannot create edit suggestions. Summaries/explanations/comparisons/translations do not offer mutation actions unless an explicit save/change request accompanies them.
- Saved-context recall, including saved guitar tabs, is kept away from public web lookup. Latest public versions, releases, prices and schedules can invoke the existing Google Search grounding tool.
- Assistant directions make the latest correction replace earlier assumptions, separate evidence from estimates, and check calculation units. Semantic recall must explain actual matching details and uncertainty.
- Failed reopening of recent attachments now stops with a reattach request; it cannot silently send a text-only request and guess about the missing file.
- Late errors from replaced native chat requests cannot overwrite the current request’s status.
- The main guide’s New additions section describes safer follow-ups and attachment handling.

Verification: 83 JavaScript/API tests and 38 Swift core tests pass. The web build and signed native Release build pass. Four simulator flows pass: separate chats/one-tap keyboard, Capture save/completion/undo, main guide/new additions/music tools, and rich headings/aligned tabs. Live checks and installation are recorded in the delivery report.

This audit focused on request validation, unsolicited actions, follow-up reasoning, recall/search routing, attachment availability, request cancellation and those native flows. It does not establish every-button coverage, consistently correct model answers or human-perceived audio quality. No new model, subscription or paid service was enabled. Private files and credentials remain excluded; the source PR stays draft and unmerged.

Research checked against [Google Search grounding documentation](https://ai.google.dev/gemini-api/docs/google-search/). The implementation uses the existing grounding integration rather than adding another provider.
