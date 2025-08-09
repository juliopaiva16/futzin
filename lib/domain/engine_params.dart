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
  static const double graphCloseBase = 0.08;
  static const double graphCloseDefenseFactor = 0.22;
  static const double graphPassTempoWidthFactor = 1.1;
  static const int    graphPassMin = 1;
  static const int    graphPassMax = 3;
  static const double graphInterceptBase = 0.10;
  static const double graphInterceptDefenseFactor = 0.18;
  static const double graphInterceptPressingFactor = 0.05;
  static const double graphInterceptDistFactor = 0.15; // weight * (d - 0.15)
  static const double graphInterceptMin = 0.02;
  static const double graphInterceptMax = 0.65;
  static const double graphFoulBase = 0.05;
  static const double graphFoulPressingFactor = 0.05;
  static const double graphRedBase = 0.03;
  static const double graphRedTempoFactor = 0.03;
  static const double graphXgBase = 0.04;
  static const double graphXgBlendAttack = 0.55; // weight for baseQual (rest for posFactor)
  static const double graphXgCoeff = 0.42; // multiplier after blend
  static const double graphXgRandomRange = 0.08; // +/- half
  static const double graphXgMin = 0.02;
  static const double graphXgMax = 0.60;
  static const double graphGoalGkSaveFactor = 0.33;
  static const double graphPGoalMin = 0.02;
  static const double graphPGoalMax = 0.78;
  static const double graphShotSaveBase = 0.52;
  static const double graphShotSaveQualityFactor = 0.18; // subtract baseQual * factor
  static const double graphShotSaveGkFactor = 0.24; // add gkSave * factor
  static const double graphDeflectOutProb = 0.18;

  // Phase 3: multi-defensor intercept parameters
  static const double graphMultiInterceptRadius = 0.18; // max distance from pass lane considered
  static const double graphMultiInterceptPerDefBase = 0.08; // base per-defender intercept component
  static const double graphMultiInterceptDefenseScale = 0.60; // scales (defense/100)
  static const double graphMultiInterceptMax = 0.80; // cap after aggregation
}
