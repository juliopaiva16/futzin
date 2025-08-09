/// Central engine parameters for the upcoming graph-based simulation.
/// Phase 1: only constants; later phases will tune.
class EngineParams {
  static const double passShortMaxDist = 0.22; // normalized field units
  static const double passLongMaxDist = 0.55;
  static const double edgeAlphaShort = 4.0; // exponential decay factor for short passes
  static const double edgeAlphaLong = 2.0;  // for long passes
  static const double interceptBase = 0.07; // base intercept scalar
  static const double tackleRadius = 0.06;  // radius for tackle/dribble contests
  static const double pressureRadius = 0.10; // neighborhood for pressure accumulation
  static const double staminaBaseDecayPerMin = 0.10; // fraction per 90m baseline
  static const double shotMaxDist = 0.35; // max effective shooting distance (normalized)
}
