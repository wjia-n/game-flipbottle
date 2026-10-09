# Flip Bottle — Rules

## 1. Objective
Flick a water bottle through the air and land it upright on the next
platform. Chain landings into streaks for points. Survive as long as you can.

## 2. Setup
- One player. The player picks a **mode** (Classic / Endless / Score Attack)
  and a **difficulty** (Rookie / Skilled / Legend) before each run.
- The bottle starts on the left platform; the target platform sits to the
  right with a gap between them.
- A power meter on the right edge ping-pongs 0→1→0 while the player holds.

## 3. Turn order
There are no turns — play is continuous. Each flip is one cycle:
`idle → charging → flying → resolving → settling → idle…`

## 4. Legal moves
- **Press and hold** anywhere on the play area: legal only from `idle`.
- **Release**: legal only while `charging`. Fires the flip with spin
  proportional to the meter value at release.
- **Cancel** (touch interrupted mid-charge): legal while `charging`;
  returns to `idle` with no penalty.

## 5. Illegal moves
- Pressing while flying/resolving/settling/game-over: ignored.
- Releasing without a charge: ignored.
- No input can skip the landing resolution or force a re-roll.

## 6. Captures
N/A — single-player skill game.

## 7. Special rules
- **Landing window:** at release, total spin = power × maxTurns × 360°.
  The bottle lands upright if the final angle is within ±tolerance of 0°.
- **Perfect zone:** within ±tolerance/3 of upright = PERFECT, double points.
- **Sweet zones on the meter** mark the power values that complete whole
  turns (0, 1/maxTurns, 2/maxTurns, …, 1).
- **Progression:** every 5 streaks raises the level: tolerance shrinks
  (min 8°), the charge meter speeds up (min 700ms period), gaps grow
  (max 0.62 of width), platforms narrow (min 0.12 of width).
- **Score Attack:** 60-second clock, unlimited flips; misses cost nothing
  but time.

## 8. Scoring
- Landing: `basePoints(difficulty) + streak × 2`, doubled on PERFECT.
- Endless mode: ×1.5 multiplier on every landing.
- Rookie base 10, Skilled base 15, Legend base 25.
- Every landing shows its points in a banner — no silent scoring.

## 9. Winning conditions
There is no terminal "win". A run ends (see §10); the victory is the new
personal best: best streak (Classic/Endless) or best score (Score Attack).

## 10. Draw conditions
N/A.

## 11. AI strategy
N/A — no opponents. Difficulty tiers ARE the challenge curve:
- **Rookie:** 30° tolerance, 1400ms meter, 3.0 max turns, short gaps.
- **Skilled:** 21° tolerance, 1100ms meter, 3.5 max turns.
- **Legend:** 13° tolerance, 880ms meter, 4.0 max turns, long gaps.

## 12. Edge cases
- Touch cancelled mid-charge → back to `idle`, no penalty, no stuck state.
- App backgrounded mid-flight → engine pauses; on resume the flight
  continues from the exact saved progress.
- A hold longer than 12s auto-releases (prevents a stranded charge).
- Every phase has an engine-owned timer; a watchdog (700ms) recovers any
  phase found without a live timer, so stuck states are impossible.
- Power exactly 0 or 1 always lands upright (0 or maxTurns full turns).

## 13. Test cases
1. Hold + release at a green zone → bottle spins whole turns, lands upright,
   points banner appears, streak +1.
2. Release far from a zone → bottle tips over, splash particles, miss
   counted, streak reset.
3. Three misses in Classic → game-over overlay with score, share button.
4. One miss in Endless → run ends immediately.
5. Score Attack: clock hits 0 → game over even mid-charge.
6. Streak reaches 5 → "LEVEL 2" snackbar, meter visibly faster.
7. Background the app mid-flight → foreground → flight resumes, no freeze.
8. Rename player → name persists across app restarts in
   `flipbottle_player_names_json` (one JSON string array via setString;
   saved on every keystroke, committed on focus loss).
9. Buy PRO (store configured) → all 12 themes, 8 bottles, 8 tables,
   theme studio and Score Attack unlock.
10. Store unconfigured → PRO screen shows an honest "after store setup"
    message, no fake buy buttons.
