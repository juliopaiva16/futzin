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
