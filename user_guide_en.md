# Futzin – User Guide

A lightweight football (soccer) match simulator with tactics, formations, xG, momentum and live event log.

- Platforms: Android, iOS, Web, macOS, Windows, Linux (Flutter).
- Languages: English and Portuguese (auto-selected by your device locale).

## 1) What you see on the screen
- Top bar: Score, minute, possession %, xG, buttons to Share, Speed, Start/Stop.
- Pitch: Team A attacks left→right (blue), Team B right→left (red). Players reflect injuries (orange fill) and yellow cards (yellow ring).
- Momentum chart: Area graph of pressure by minute (blue = Team A, red = Team B) with markers for goals, shots, cards and injuries.
- Event log: Natural language description of actions minute-by-minute.

## 2) Controls
- Start match: Plays a 90-minute simulation.
- Stop: Halts the current match.
- Speed: 1x, 1.5x, 2x, 4x, 10x (applies immediately to the running match).
- Share: Exports the full match log, including score and xG.

## 3) Squads, formations and substitutions
- Valid lineup: 11 players; exactly 1 goalkeeper; defenders/midfielders/forwards must match the chosen formation.
- Formations available: 4-3-3, 4-4-2, 3-5-2, 5-3-2, 4-2-3-1 (midfield split 2+3).
- Substitutions: Up to 5 per match. You cannot replace a sent-off player; injured players are removed from the field and should be manually replaced.
- Auto-pick: Automatically selects the best available players per role.

## 4) Player attributes and stamina
- Attack: offensive contribution (most impactful for forwards, then midfielders, slightly for defenders).
- Defense: defensive contribution (most impactful for defenders and goalkeeper, then midfielders, slightly for forwards).
- Stamina: modifies how effective attributes are during the match.
  - Effective attribute = base × (0.60 + 0.40 × stamina/100).
- Fatigue per in-game minute increases with Tempo and Pressing. High tempo/pressing drains stamina faster.

## 5) Tactics (trade-offs)
- Attack Bias (−1..+1): increases attack but reduces defense (moderately).
- Tempo (0..1): more events per minute, more quick passes, higher fatigue.
- Pressing (0..1): better defense due to pressure, higher fatigue.
- Line Height (0..1): slightly boosts attack and slightly lowers defense; also shifts visual player positions forward/back.
- Width (0..1): slightly boosts attack, slightly lowers defense; visually spreads players more vertically.

## 6) How a minute is simulated
- Each minute can be calm or have an attacking sequence.
- Calm minute: possession split ~50/50 and a neutral log line.
- With attack: which team attacks is based on team Attack vs opponent Defense.
- Sequence: find space → 0–2 quick passes (with possible interception) → potential foul (yellow/red; sometimes second yellow) and injury → shot.
- xG (expected goals): 0.03–0.65 based on attack vs defense; goalkeeper quality reduces scoring probability.
- Non-goal shots become Saved/Deflected/Off Target in the log.

## 7) Possession and momentum
- Possession: minutes without attacks give ~30s to each team; attacking minutes attribute ~20–60s with ~65% to the attacking side.
- Momentum chart:
  - Blue area above midline = Team A on top; red area below = Team B.
  - Markers: ball (goal), triangle (shot), yellow/red card, orange cross (injury).
  - Taller areas = stronger momentum in recent minutes. Clustered triangles without balls often means keeper saves or poor finishing.

## 8) Strategy tips
- Underdog setup: slightly defensive bias, lower line, moderate width, moderate pressing, lower tempo to reduce event volume.
- Favorite setup: positive bias, higher line, wider width, higher tempo, medium/high pressing. Watch stamina and cards.
- Sub management: with high tempo/pressing, plan to refresh the team mid-second half. Replace players on a yellow if risky.
- Formations:
  - 4-2-3-1: balance between protection (double pivot) and chance creation (3 AMs).
  - 4-3-3: pressure up top with wide forwards.
  - 3-5-2: strong in midfield; 5-3-2: extra solidity in defense.

## 9) FAQ
- Why do repeats yield different results? The simulator is stochastic. Outcomes vary by random seed.
- What is xG? Expected Goals – the chance a shot would result in a goal, based on context.
- Why can’t I sub a sent-off player? Red cards permanently reduce players on the field.
- Does the app persist my squads? Yes, lineups and squads are saved locally.
- How to reset? Edit squad/lineup manually or clear the app’s local storage.

## 10) Known limits
- 90-minute regulation time; no extra time/penalties.
- Manual substitutions only (up to 5).

Enjoy the game! If you like Futzin, share your classic matches.
