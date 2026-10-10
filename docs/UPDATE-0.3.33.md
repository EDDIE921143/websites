# 0.3.33 — Practical student learning context

Each student profile now has Current classroom topic, Where they need practice, What they can already do and Next session goal. Edit student stores these fields alongside the existing profile without discarding extra data. A Learning context section on their journal makes the information visible and editable. Unknown details can remain empty.

Mentor Bot uses the selected student’s profile, relevant session notes and upcoming tests to prepare a brief or a lesson. Its directions include a quick understanding check, worked example, guided practice, independent check and next step. Requested exercises include a separate answer key with checked reasoning. It should distinguish observed progress from guesses, flag contradictory/stale notes and avoid inventing grades, dates, learning needs or curriculum. Saved changes still require review. The retrieval catalogue now includes a short current-topic and next-step hint, within the existing student boundary.

This follows [EEF tutoring guidance](https://educationendowmentfoundation.org.uk/education-evidence/effective-tutoring/) on connecting tuition to classroom content and specific needs, and [feedback guidance](https://educationendowmentfoundation.org.uk/education-evidence/guidance-reports/feedback) on identifying learning gaps. These are design decisions informed by research, not evidence that an AI answer or educational outcome is guaranteed. No extra paid services or plugins were installed.

Example: set Classroom topic to Adding fractions, Needs practice to Finding a common denominator, Already comfortable with to Equivalent fractions, and Next session to Solve one problem independently. Then ask their bot: Give me a 20-minute session plan and three practice questions. The bot receives these saved details rather than assuming a student’s needs from their name.

Validation and delivery status are recorded in the local update report. The existing spoken Mentor guide and separate practice workspace remain available. No private student data, credentials or local handoff are committed.
