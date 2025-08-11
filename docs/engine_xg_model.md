# xG Model (Multi-Feature Blend)
Features:
- Distance / positional factor (posFactor = 1 - |x_goal - x|).
- Angle centrality (1 - |y-0.5|*2).
- Pressure (nearby defenders within radius with defense weight).
- Assist context (short bonus, long pass penalty, dribble bonus, fallback shot penalty).
- Legacy quality (attack vs defense rating) blended for stability.

Computation:
featXg = base + w_dist*pos + w_ang*angle
featXg *= (1 - w_press*pressure)
featXg += assistAdj
featXg *= scaling
xg = blendLegacy*legacyXg + (1-blendLegacy)*featXg
if forcedFallback: xg *= fallbackRel
Clamp to [graphXgMin, graphXgMax].

pGoal = clamp(xg * (0.85 - gkFactor*save) * abilityMods * earlyShotDamp, pGoalMin,pGoalMax).

Ability modifiers (current): FIN (+rel), CAT (-rel), PC role (+3%).
