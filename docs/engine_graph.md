# Graph Engine
Micro action loop modeling spatial decisions.

Phases implemented: roles/coords, short pass + shot, weighted edges & multi-def intercept, extended actions, core abilities integration, stamina partial, xG/momentum tuning ongoing.

Pipeline (per possession loop):
1. Ensure coordinates (assign if null).
2. Select starter (FWD > MID > any).
3. For iteration i < passMax:
   - Enumerate candidate actions {short,long,dribble,back,hold,launch} under caps.
   - Score actions (base weights + adaptive boost + ability modifiers).
   - If dribble: resolve success; on success maybe adaptiveBoost.
   - If pass: compute interception: base + defenseFactor + pressing + multi-def lane model; apply tempo/width mitigations + ability modifiers.
   - Maintain forward progress tracker.
   - Early shot trigger if progress & passesSoFar≥2.
4. Forced/fallback shot if passMax reached or stagnation.
5. Shot resolution: multi-feature xG blend (distance, angle, pressure, assist, fallback penalty) → pGoal with GK/FIN/CAT modifiers + early shot dampening.
6. Log action (JSONL) then repeat for next possession.

Caps: dribbles ≤ graphActionMaxDribblesPerSeq, long passes ≤ graphActionMaxLongPerSeq.

Multi-def intercept (v2): complement aggregation over defenders in lane window (t range) with per-def proximity & defense scaling, capped by graphMultiInterceptMaxV2.
