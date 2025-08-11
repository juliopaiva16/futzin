# Legacy Engine
Minute classified calm vs attacking. Attacking minute triggers sequence builder selecting attackers, passes, potential fouls, shot resolution.

Core formulas:
- Close defense check: closeChance = legacyCloseBase + legacyCloseDefenseFactor * (defAdj/(attAdj+defAdj)).
- Pass count: base = 1 + (tempo+width)*legacyPassTempoWidthFactor (randomized ±1), clamped [0,legacyPassMax].
- Intercept per pass: legacyInterceptBase + legacyInterceptDefenseFactor * (defAdj/(attAdj+defAdj)).
- xG: clamp(legacyXgBase + legacyXgAttackFactor * quality + noise, min,max) where quality = attAdj/(attAdj+defAdj).
- Goal prob: clamp(xG * (0.95 - legacyGoalGkSaveFactor * gkSave), pGoalMin,pGoalMax).

Used primarily for regression baseline & fallback until graph engine deprecates it.
