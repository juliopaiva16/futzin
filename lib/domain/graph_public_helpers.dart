/// MT5: Multi-feature xG model public helper
class ShotModelFeatResult { final double xg; final double legacyXg; ShotModelFeatResult(this.xg,this.legacyXg); }

ShotModelFeatResult graphComputeMultiFeatureXg({
  required Player carrier,
  required Iterable<Player> defAlive,
  required double baseQual,
  required double posFactor,
  required bool adaptiveBoost,
  required bool forcedFallback,
  required int usedLong,
  required int passesSoFar,
  double? carrierY,
}) {
  carrierY ??= (carrier.y ?? 0.5).clamp(0.0, 1.0);
  final angleCentrality = 1.0 - ((carrierY - 0.5).abs() * 2.0).clamp(0.0, 1.0);
  double pressureScore = 0.0;
  if (defAlive.isNotEmpty) {
    int nearby = 0;
    double avgDef = 0.0;
    for (final dPlayer in defAlive) {
      final dx = ((dPlayer.x ?? 0.5) - (carrier.x ?? 0.5));
      final dy = ((dPlayer.y ?? 0.5) - (carrier.y ?? 0.5));
      final distD = sqrt(dx*dx + dy*dy);
      if (distD < EngineParams.graphXgFeatPressureRadius) {
        nearby++;
        avgDef += dPlayer.defense;
      }
    }
    if (nearby > 0) avgDef /= nearby;
    pressureScore = (nearby * EngineParams.graphXgFeatPressurePerDef * (1.0 + (avgDef/100.0)*0.15)).clamp(0.0, 1.0);
  }
  double assistAdj = 0.0;
  if (passesSoFar > 0) {
    if (usedLong > 0) {
      assistAdj += EngineParams.graphXgFeatAssistLongPenalty;
    } else if (passesSoFar == 1) {
      assistAdj += EngineParams.graphXgFeatAssistShortBonus;
    } else {
      assistAdj += EngineParams.graphXgFeatAssistShortBonus * 0.5;
    }
  }
  if (adaptiveBoost) assistAdj += EngineParams.graphXgFeatAssistDribbleBonus;
  if (forcedFallback) assistAdj += EngineParams.graphXgFeatForcedShotPenalty;
  double featXg = EngineParams.graphXgFeatBase;
  featXg += EngineParams.graphXgFeatDistanceWeight * posFactor;
  featXg += EngineParams.graphXgFeatAngleWeight * angleCentrality;
  featXg *= (1.0 - EngineParams.graphXgFeatPressureWeight * pressureScore);
  featXg += assistAdj;
  featXg *= EngineParams.graphXgFeatScaling;
  double legacyXg = EngineParams.graphXgBase + EngineParams.graphXgCoeff * (EngineParams.graphXgBlendAttack * baseQual + (1 - EngineParams.graphXgBlendAttack) * posFactor);
  double xg = (EngineParams.graphXgFeatBlendLegacy * legacyXg + (1 - EngineParams.graphXgFeatBlendLegacy) * featXg)
      .clamp(EngineParams.graphXgMin, EngineParams.graphXgMax);
  if (forcedFallback) xg *= EngineParams.graphFallbackLongShotXgRel;
  return ShotModelFeatResult(xg, legacyXg);
}
/// Standalone public helpers for graph engine probability computations.
library;

import 'dart:math';
import 'engine_params.dart';
import 'entities.dart';
import 'match_engine.dart';

// Multi-defender interception probability (Phase 3 model v2)
double graphMultiDefInterceptProb(Player from, Player to, Iterable<Player> defenders) {
  double segDist(Player d) {
    final fx = from.x ?? 0.5, fy = from.y ?? 0.5;
    final tx = to.x ?? 0.5, ty = to.y ?? 0.5;
    final dx = tx - fx; final dy = ty - fy;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return 999;
    final pdx = (d.x ?? 0.5) - fx; final pdy = (d.y ?? 0.5) - fy;
    final tRaw = ((pdx * dx) + (pdy * dy)) / (dx*dx + dy*dy);
    final t = tRaw.clamp(0.0, 1.0);
    if (t < EngineParams.graphMultiInterceptLaneTMinV2 || t > EngineParams.graphMultiInterceptLaneTMaxV2) return 999;
    final cx = fx + dx * t; final cy = fy + dy * t;
    final ddx = (d.x ?? 0.5) - cx; final ddy = (d.y ?? 0.5) - cy;
    return sqrt(ddx*ddx + ddy*ddy);
  }
  final radius = EngineParams.graphMultiInterceptRadiusV2;
  double nonInterceptProd = 1.0;
  for (final d in defenders) {
    if (d.sentOff || d.injured) continue;
    final distLane = segDist(d);
    if (distLane > radius) continue;
    final defFactor = (d.defense / 100.0) * EngineParams.graphMultiInterceptDefenseScaleV2;
    final proximity = 1.0 - distLane / radius;
    double p = EngineParams.graphMultiInterceptPerDefBaseV2 * (1.0 + defFactor) * proximity;
    p = p.clamp(0.0, 0.25);
    nonInterceptProd *= (1.0 - p);
  }
  final agg = 1.0 - nonInterceptProd;
  return agg.clamp(0.0, EngineParams.graphMultiInterceptMaxV2);
}

class ShotModelResult { final double xg; final double pGoal; ShotModelResult(this.xg,this.pGoal); }

/// MT5 multi-feature xG computation (public helper) blending legacy + feature model.
ShotModelResult graphComputeShotModelMultiFeature({
  required MatchEngine eng,
  required Player carrier,
  required PublicTeamRatings atk,
  required PublicTeamRatings def,
  required bool attackingTeamA,
  bool forcedFallback = false,
  int passesSoFar = 0,
  bool dribbleAssist = false,
  bool usedLong = false,
  Iterable<Player>? defAlive,
}) {
  final rng = eng.rng; final goalX = attackingTeamA ? 1.0 : 0.0;
  final dxGoal = (goalX - (carrier.x ?? 0.5)).abs().clamp(0.0, 1.0);
  final baseQual = atk.attack / (atk.attack + def.defense + 1e-6);
  final posFactor = (1.0 - dxGoal);
  double legacyXg = EngineParams.graphXgBase + EngineParams.graphXgCoeff * (EngineParams.graphXgBlendAttack * baseQual + (1 - EngineParams.graphXgBlendAttack) * posFactor) + (rng.nextDouble() * EngineParams.graphXgRandomRange - EngineParams.graphXgRandomRange / 2);
  legacyXg = legacyXg.clamp(EngineParams.graphXgMin, EngineParams.graphXgMax);
  final carrierY = (carrier.y ?? 0.5).clamp(0.0, 1.0);
  final angleCentrality = 1.0 - ((carrierY - 0.5).abs() * 2.0).clamp(0.0, 1.0);
  double pressureScore = 0.0;
  if (defAlive != null && defAlive.isNotEmpty) {
    int nearby = 0; double weighted = 0.0;
    for (final d in defAlive) {
      if (d.sentOff || d.injured) continue;
      final dx = ((d.x ?? 0.5) - (carrier.x ?? 0.5));
      final dy = ((d.y ?? 0.5) - (carrier.y ?? 0.5));
      final distD = sqrt(dx*dx + dy*dy);
      if (distD < EngineParams.graphXgFeatPressureRadius) {
        nearby++;
        weighted += (d.defense / 100.0) * EngineParams.graphXgFeatPressureDefenseWeight;
      }
    }
    if (nearby > 0) {
      pressureScore = ((nearby * EngineParams.graphXgFeatPressurePerDef) * (1.0 + (weighted/nearby)*0.25)).clamp(0.0, 1.0);
    }
  }
  double assistAdj = 0.0;
  if (passesSoFar > 0) {
    if (usedLong) assistAdj += EngineParams.graphXgFeatAssistLongPenalty;
    else if (passesSoFar == 1) assistAdj += EngineParams.graphXgFeatAssistShortBonus;
    else assistAdj += EngineParams.graphXgFeatAssistShortBonus * 0.5;
  }
  if (dribbleAssist) assistAdj += EngineParams.graphXgFeatAssistDribbleBonus;
  if (forcedFallback) assistAdj += EngineParams.graphXgFeatForcedShotPenalty;
  double featXg = EngineParams.graphXgFeatBase;
  featXg += EngineParams.graphXgFeatDistanceWeight * posFactor;
  featXg += EngineParams.graphXgFeatAngleWeight * angleCentrality;
  featXg *= (1.0 - EngineParams.graphXgFeatPressureWeight * pressureScore);
  featXg += assistAdj;
  double xg = (EngineParams.graphXgFeatBlendLegacy * legacyXg + (1 - EngineParams.graphXgFeatBlendLegacy) * featXg)
      .clamp(EngineParams.graphXgMin, EngineParams.graphXgMax);
  if (forcedFallback) xg *= EngineParams.graphFallbackLongShotXgRel;
  final gkSave = ((def.gk?.defense ?? 55) / 100.0);
  double pGoal = (xg * (0.85 - EngineParams.graphGoalGkSaveFactor * gkSave * 1.10)).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  if (carrier.hasAbility('FIN')) pGoal = (pGoal * (1.0 + EngineParams.graphAbilityFinPGoalRel)).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  if (def.gk != null && def.gk!.hasAbility('CAT')) pGoal = (pGoal * (1.0 - EngineParams.graphAbilityCatSaveRel)).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  if (carrier.role == Role.FWD_PC) pGoal = (pGoal * 1.03).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  return ShotModelResult(xg, pGoal);
}

/// Public ratings wrapper for testing / helpers without exposing private class.
class PublicTeamRatings { final double attack; final double defense; final Player? gk; const PublicTeamRatings({required this.attack, required this.defense, this.gk}); }

ShotModelResult graphComputeShotModel({required MatchEngine eng, required Player carrier, required PublicTeamRatings atk, required PublicTeamRatings def, required bool attackingTeamA}) {
  final rng = eng.rng; final goalX = attackingTeamA ? 1.0 : 0.0;
  final dxGoal = (goalX - (carrier.x ?? 0.5)).abs().clamp(0.0, 1.0);
  final baseQual = atk.attack / (atk.attack + def.defense + 1e-6);
  final posFactor = (1.0 - dxGoal);
  double xg = EngineParams.graphXgBase + EngineParams.graphXgCoeff * (EngineParams.graphXgBlendAttack * baseQual + (1 - EngineParams.graphXgBlendAttack) * posFactor) + (rng.nextDouble() * EngineParams.graphXgRandomRange - EngineParams.graphXgRandomRange / 2);
  xg = xg.clamp(EngineParams.graphXgMin, EngineParams.graphXgMax);
  final gkSave = ((def.gk?.defense ?? 55) / 100.0);
  double pGoal = (xg * (0.95 - EngineParams.graphGoalGkSaveFactor * gkSave)).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  if (carrier.hasAbility('FIN')) pGoal = (pGoal * (1.0 + EngineParams.graphAbilityFinPGoalRel)).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  if (def.gk != null && def.gk!.hasAbility('CAT')) pGoal = (pGoal * (1.0 - EngineParams.graphAbilityCatSaveRel)).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  if (carrier.role == Role.FWD_PC) pGoal = (pGoal * 1.03).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  return ShotModelResult(xg, pGoal);
}

/// Public helper (Phase 6) to compute per-minute fatigue cost for a player under given tactics.
/// Mirrors private _computeMinuteFatigue used internally so tests can validate ENG effect.
double graphComputeMinuteFatigue({required Player player, required Tactics tactics}) {
  final tempo = tactics.tempo.clamp(0.0, 1.0);
  final pressing = tactics.pressing.clamp(0.0, 1.0);
  final riskProxy = (tactics.attackBias.abs() * 0.5 + tempo * 0.3 + pressing * 0.2).clamp(0.0, 1.0);
  const baseCost = 0.08; // keep in sync with _computeMinuteFatigue
  double variable = EngineParams.staminaTempoDecayFactor * tempo * 0.07
      + EngineParams.staminaPressingDecayFactor * pressing * 0.06
      + EngineParams.staminaRiskProxyFactor * riskProxy * 0.05;
  if (player.hasAbility('ENG')) {
    variable *= (1 - EngineParams.graphAbilityEngStaminaDecayRel);
  }
  double cost = (baseCost + variable).clamp(0.05, 0.22);
  switch (player.role) {
    case Role.MID_B2B:
      cost *= 0.95; // -5%
      break;
    case Role.MID_WB:
      cost *= 1.03; // +3%
      break;
    default:
      break;
  }
  return cost;
}

/// MT4: approximate single-pass intercept chance (excluding multi-def lane component) to test mitigation effects.
double graphApproxInterceptChance({required double baseAttackAdj, required double baseDefenseAdj, required double defPressing, required double atkTempo, required double atkWidth}) {
  double interceptBase = EngineParams.graphInterceptBase + EngineParams.graphInterceptDefenseFactor * (baseDefenseAdj / (baseAttackAdj + baseDefenseAdj)) + EngineParams.graphInterceptPressingFactor * defPressing;
  final lowTempoMit = (1.0 - EngineParams.graphInterceptTempoLowMitigation * (1.0 - atkTempo));
  final highWidthMit = (1.0 - EngineParams.graphInterceptWidthMitigation * atkWidth);
  interceptBase *= lowTempoMit * highWidthMit;
  return interceptBase.clamp(EngineParams.graphInterceptMin, EngineParams.graphInterceptMax);
}
