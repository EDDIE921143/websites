# 0.3.28 — Ediz’s five-day plan and clearer Gym guide

Gym now follows the five training days Ediz specified, in this order:

| Day | Exercises in order |
|---|---|
| 1 · Chest | Lever chest press; seated fly; seated shoulder press; lateral raise; lever seated dip; extra decline sit-up |
| 2 · Back | Seated row; bar lateral pull-down; lever seated reverse fly; extra decline sit-up; shrug; lever preacher curl |
| 3 · Legs | Seated leg curl; seated leg press; seated hip adduction; leg extension; seated calf raise |
| 4 · Back & chest | Chest press; seated fly; seated row; lateral pull-down; extra decline sit-up |
| 5 · Arms | Tricep dip; preacher curl; overhead tricep extension; hammer curl; cable pushdown; dumbbell incline curl; one-arm wrist curl; one-arm reverse wrist curl |

The weekday placement is Monday chest, Tuesday back, Thursday legs, Friday back and chest, Saturday arms. Wednesday and Sunday are recovery days. The existing weekday editor still lets you move workouts. The fourth-day ab exercise uses the same decline sit-up. The last arm exercise uses the existing reverse wrist curl entry.

## Existing saved plans

The new revision applies once to installed saved plans, not just new users. The previous Gym state is retained in a backup preference. Matching exercises keep their sets, rest time, repetition targets and superset labels. Workout history, an active workout, custom exercises, scheduled dates and alert preferences survive. New plan entry IDs invalidate obsolete assistant suggestions. After migration, manual plan edits stay saved on relaunch. Corrupt saved state is kept and reported rather than replaced.

## Tutorial

Gym settings → Learn your Gym now covers ten shorter lessons: the five-day split, moving days, adding movements, real demonstrations, editing targets, logging sets, rest and supersets, finishing and History, reviewed Gym Bot changes, and a closing lesson. All ten have fresh bundled Aoede recordings that play offline. Practice controls never change the real workout. Skip practice lets experienced users continue without filling every example.

Guide speed is shared across the main walkthrough, Notes Lab, New additions and Gym. The default is 1.15×, with 1× and 1.3× choices in Settings → Guide voice and directly in the Gym guide. Replay, Back and Continue remain visible in a fixed bottom control area. Up/Down buttons reorder exercises; the calendar menu moves one exercise to another day while retaining its targets. The existing transitions respect Reduce Motion.

| Before | After | Why |
|---|---|---|
| Four-day plan with misplaced arm/leg exercises | Exact five-day split, including back and chest on Day 4 | Follows the user’s actual plan |
| Longer eight-part Gym guide | Ten focused lessons with shorter natural narration | Explains more controls without long individual speeches |
| Fixed narration pace | Shared 1×, 1.15× and 1.3× speeds | Lets the guide move at a comfortable pace |
| Practice requirement blocks progress | Optional Skip practice | Makes revisiting features faster |

## Verification

41 Swift core tests, 89 JavaScript/API tests, the web build and signed Release build pass. Physical checks verify the five workout weekdays, Wednesday/Sunday rest, visible exercise movement, removal and persistence after relaunch. The full ten-step tutorial is checked separately in an isolated simulator; delivery status and any limitations are recorded in the update report. No backend changes are required for this native update. Human assessment of the new narration remains separate from automated playback checks.
