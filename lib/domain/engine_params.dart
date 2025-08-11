/// Central engine parameters for the upcoming graph-based simulation.
/// Phase 1: only constants; later phases will tune.
class EngineParams {
  // Graph / spatial constants
  static const double passShortMaxDist = 0.22; // normalized field units
  static const double passLongMaxDist = 0.55;
  static const double edgeAlphaShort = 4.0; // exponential decay factor for short passes
  static const double edgeAlphaLong = 2.0;  // for long passes
  static const double interceptBase = 0.07; // base intercept scalar
  static const double tackleRadius = 0.06;  // radius for tackle/dribble contests
  static const double pressureRadius = 0.10; // neighborhood for pressure accumulation
  static const double staminaBaseDecayPerMin = 0.10; // fraction per 90m baseline
  static const double shotMaxDist = 0.35; // max effective shooting distance (normalized)

  // Legacy minute engine (centralized for tuning & tests)
  static const double legacyBaseEventChance = 0.28; // baseline attacking minute probability
  static const double legacyTempoEventFactor = 0.27; // added * avg tempo (0..1)
  static const double legacyCalmPossSeconds = 30.0; // calm minute possession seconds per side
  static const double legacySeqMinSeconds = 20.0; // min sequence duration
  static const double legacySeqPerSubEventSeconds = 4.0; // add per sub-event (text/pass etc.)
  static const double legacySeqMaxSeconds = 60.0; // cap sequence duration
  static const double legacySeqPossShare = 0.65; // share to attacker during attacking minute

  // Legacy sequence tuning
  static const double legacyCloseBase = 0.10;
  static const double legacyCloseDefenseFactor = 0.25;
  static const double legacyPassTempoWidthFactor = 1.2; // multiplier inside passBase
  static const int    legacyPassExtraRand = 2; // rng.nextInt(2)
  static const int    legacyPassMax = 2;
  static const double legacyInterceptBase = 0.14;
  static const double legacyInterceptDefenseFactor = 0.20;
  static const double legacyFoulBase = 0.06;
  static const double legacyFoulPressingFactor = 0.04;
  static const double legacyRedBase = 0.04;
  static const double legacyRedTempoFactor = 0.03;
  static const double legacySecondYellowProb = 0.05;
  static const double legacyInjuryAfterFoulProb = 0.12;
  static const double legacyXgBase = 0.05;
  static const double legacyXgAttackFactor = 0.45;
  static const double legacyXgRandomRange = 0.10; // +/- half
  static const double legacyXgMin = 0.03;
  static const double legacyXgMax = 0.65;
  static const double legacyGoalGkSaveFactor = 0.35; // multiplied inside (0.95 - factor * gkSave)
  static const double legacyPGoalMin = 0.02;
  static const double legacyPGoalMax = 0.80;
  static const double legacyShotSaveBase = 0.55;
  static const double legacyShotSaveQualityFactor = 0.20; // subtract quality * factor
  static const double legacyShotSaveGkFactor = 0.25; // add gkSave * factor
  static const double legacyDeflectOutProb = 0.20;

  // Graph sequence tuning (Phase 2 experimental)
  static const double graphCloseBase = 0.06; // tuned down to increase sequences
  static const double graphCloseDefenseFactor = 0.17; // slightly reduced to allow more sequences
  static const double graphPassTempoWidthFactor = 1.1;
  static const int    graphPassMin = 1;
  static const int    graphPassMax = 5; // allow longer chains to raise shot volume
  // Interception probabilities still a bit high (pass success ~72% < target 75-88%).
  // Soften further to raise pass completion.
  // Backlog (item 14): interceptBase 0.064 -> 0.062 for slight pass success uplift
  static const double graphInterceptBase = 0.062; // Tuning7 pre-pass-success window
  static const double graphInterceptDefenseFactor = 0.145; // softened
  static const double graphInterceptPressingFactor = 0.032; // softened
  static const double graphInterceptDistFactor = 0.10; // unchanged
  static const double graphInterceptMin = 0.02;
  static const double graphInterceptMax = 0.65;
  static const double graphFoulBase = 0.05;
  static const double graphFoulPressingFactor = 0.05;
  static const double graphRedBase = 0.03;
  static const double graphRedTempoFactor = 0.03;
  // Backlog (item 15): raise xG base & shift blend toward position
  static const double graphXgBase = 0.065; // raised to lift reported xG
  static const double graphXgBlendAttack = 0.48; // more weight to positional factor
  // Raise xG reporting (was undershooting vs actual goals) without inflating goals:
  static const double graphXgCoeff = 0.80; // moderate xG scale
  static const double graphXgRandomRange = 0.08; // +/- half
  static const double graphXgMin = 0.02;
  static const double graphXgMax = 0.70; // trim ceiling a bit
  static const double graphGoalGkSaveFactor = 0.33;
  static const double graphPGoalMin = 0.02;
  // Slightly reduce finishing ceiling to curb conversion (>25% was high):
  static const double graphPGoalMax = 0.70; // reduce finishing ceiling
  static const double graphShotSaveBase = 0.52;
  static const double graphShotSaveQualityFactor = 0.18; // subtract baseQual * factor
  static const double graphShotSaveGkFactor = 0.24; // add gkSave * factor
  static const double graphDeflectOutProb = 0.18;

  // Phase 3: multi-defensor intercept parameters
  static const double graphMultiInterceptRadius = 0.18; // max distance from pass lane considered
  static const double graphMultiInterceptPerDefBase = 0.08; // base per-defender intercept component
  static const double graphMultiInterceptDefenseScale = 0.60; // scales (defense/100)
  static const double graphMultiInterceptMax = 0.80; // cap after aggregation

  // Retuned (v2) multi-defender interception (softer aggregation)
  static const double graphMultiInterceptRadiusV2 = 0.12; // was 0.13
  static const double graphMultiInterceptPerDefBaseV2 = 0.016; // softened
  static const double graphMultiInterceptDefenseScaleV2 = 0.40; // unchanged
  static const double graphMultiInterceptLaneTMinV2 = 0.10; // narrower window (was 0.08)
  static const double graphMultiInterceptLaneTMaxV2 = 0.90; // narrower window (was 0.92)
  // Backlog (item 14): multi-cap 0.28 -> 0.26 to push pass success upward
  static const double graphMultiInterceptMaxV2 = 0.26;

  // Graph edge weighting (Phase 3: congestion-aware pass selection)
  static const double graphEdgeCongestionRadius = 0.12; // radius around mid pass point
  static const double graphEdgeCongestionDefScale = 0.35; // weight reduction per local density (capped)

  // Phase 4 action selection weights
  static const double graphActionShortBase = 1.62; // was 1.55 (tuning step 1)
  // Increase dribble weight to raise attempts (~4.8 -> aim 8-12 per match):
  static const double graphActionDribbleBase = 0.26; // slight bump to lift attempts
  static const double graphActionLongPassBase = 0.06; // was 0.08
  static const double graphActionBackPassBase = 0.09; // unchanged
  static const double graphActionHoldBase = 0.07; // unchanged
  static const double graphActionLaunchBase = 0.015; // was 0.02
  // Adaptive boost after a successful risky action (dribble/long/launch retain)
  static const double graphAdaptiveShortBoost = 0.40; // new: extra short weight next decision
  static const int graphActionMaxDribblesPerSeq = 3; // unchanged
  static const int graphActionMaxLongPerSeq = 1;
  static const double graphBackPassInterceptFactor = 0.60; // safer (was 0.65)
  static const double graphHoldExtraPassWeight = 0.78; // was 0.70 (tuning step 5)
  // Distance thresholds for action modulation
  static const double graphDribbleMaxDist = 0.16; // only consider dribble if defender within
  static const double graphLongPassMinDist = 0.28; // candidate receiver >= this
  static const double graphLaunchTriggerDist = 0.34; // if no good short options
  // Dribble resolution parameters
  static const double graphDribbleSuccessBase = 0.50; // reduce average success a bit
  static const double graphDribbleAttackSkillScale = 0.30; // (technique/100)*scale additive
  static const double graphDribbleDefSkillScale = 0.38; // increase defensive impact
  static const double graphDribblePaceScale = 0.20; // (pace diff /100)*scale additive
  static const double graphDribbleSuccessMin = 0.15;
  static const double graphDribbleSuccessMax = 0.85;
  // Long pass success model (simplified for phase 4)
  static const double graphLongPassBaseSuccess = 0.80; // was 0.76
  static const double graphLongPassDistPenalty = 0.42; // was 0.45
  static const double graphLongPassDefenseContest = 0.06; // was 0.08
  // Launch (50/50) parameters
  static const double graphLaunchWinProb = 0.48; // probability retaining possession after launch
  // Hold/back pass modest intercept risk reduction (removed duplicate older defs below)

  // Ability modifiers (Phase 5)
  // Backlog (item 14): VIS 0.10->0.12, PAS short 0.05->0.06
  static const double graphAbilityVisInterceptRel = 0.12; // VIS stronger reduction
  static const double graphAbilityPasShortRel = 0.06; // PAS stronger short/back reduction
  static const double graphAbilityPasLongSuccess = 0.03; // PAS increases long pass success abs before clamp
  static const double graphAbilityDrbSuccessAdd = 0.025; // slight further nerf to keep ability success <=60%
  static const double graphAbilityDrbExtraWeight = 0.15; // DRB extra dribble action weight multiplier
  static const double graphAbilityFinPGoalRel = 0.05; // reduce FIN relative boost
  static const double graphAbilityWallInterceptRel = 0.05; // WALL defenders increase intercept rel (once)
  static const double graphAbilityCatSaveRel = 0.06; // CAT reduces pGoal rel
  static const double graphAbilityEngStaminaDecayRel = 0.05; // target ~15% relative decay reduction overall (Tuning6)
  // Newly scaffolded abilities (placeholders, effects = 0.0 until tuning phase)
  static const double graphAbilityMrkInterceptRel = 0.0; // MRK: extra intercept relative boost (def field players)
  static const double graphAbilityAerGkSaveRel = 0.0;    // AER: aerial GK save / high ball influence
  static const double graphAbilityRefGkSaveRel = 0.0;    // REF: GK reflex save relative reduction to pGoal
  static const double graphAbilityComGkSaveRel = 0.0;    // COM: GK composure lowers rebound/off-target variance (proxy: save rel)
  static const double graphAbilityHdrShotXgAdd = 0.0;    // HDR: add small xG for header-like (distance > threshold) shots
  static const double graphAbilityCltLatePGoalRel = 0.0; // CLT: late-game pGoal relative boost (>=75')
  static const double graphAbilitySprDribblePaceRel = 0.0; // SPR: increases pace component in dribble success

  // Early shot tuning (Phase 6 provisional)
  // Boost shot volume (currently ~12.3, target 18-25) by allowing earlier & more frequent shots.
  static const double graphEarlyShotDist = 0.28; // unchanged
  static const double graphEarlyShotProb = 0.40; // modest raise while retaining early pGoal dampening (Tuning6)
  static const double graphAbilityCapTeamAdj = 0.03; // CAP small team attack/defense adj
  // Post-dribble & fallback shot controls (Backlog items 11-13 partially)
  // MT3: dynamic post-dribble & forced shot controls
  static const double graphPostDribbleShotProbBase = 0.10; // base chance of immediate shot after successful dribble
  static const double graphPostDribbleShotProbNearGoalBonus = 0.07; // additive if very close
  static const double graphPostDribbleShotMaxDist = 0.34; // within this dist eligible for immediate shot
  static const double graphPostDribbleShotDistNearGoal = 0.18; // near-goal threshold for bonus
  static const double graphFallbackLongShotXgRel = 0.85; // damp xG for forced long/low-quality shot
  static const bool   graphForcedShotEnabled = true; // allow early forced shot if sequence stalls
  static const int    graphForcedShotMinPasses = 4; // after this many passes without progress, force shot
  static const double graphForcedShotProgressThreshold = 0.015; // min x progress to count as advancement

  // Phase 6 stamina model factors (minute-level decay components)
  static const double staminaTempoDecayFactor = 0.34; // scales tempo (0..1)
  static const double staminaPressingDecayFactor = 0.28; // scales pressing (0..1)
  static const double staminaRiskProxyFactor = 0.12; // proxy for risky actions (long/dribble/launch) until micro-tracking
  // Logging (MT1) 0=off 1=summary 2=detailed (future expansion)
  static const int graphLoggingMode = 1;
}
