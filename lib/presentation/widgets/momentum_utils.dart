import 'package:flutter/material.dart' show debugPrint; // for optional debug logging

import '../../domain/match_engine.dart';
import '../../domain/engine_params.dart';

/// Compute per-minute momentum series from match events.
/// Uses event.momentumDelta when present; otherwise falls back to legacy mapping.
/// Returns a list sized [maxMinutes+1], index 1..maxMinutes.
List<double> computeMomentumSeries(List<MatchEvent> events, int maxMinutes) {
  final minuteScores = List<double>.filled(maxMinutes + 1, 0.0);
  for (final e in events) {
    final m = e.minute.clamp(1, maxMinutes).toInt();
    final sideSign = e.side > 0 ? 1.0 : (e.side < 0 ? -1.0 : 0.0);
    if (e.momentumDelta != null) {
      minuteScores[m] += e.momentumDelta!;
      continue;
    }
    switch (e.kind) {
      case MatchEventKind.goal:
        minuteScores[m] += sideSign * EngineParams.momentumGoal;
        break;
      case MatchEventKind.shot:
        final w = EngineParams.momentumShotBase + EngineParams.momentumShotXgScale * (e.shotXg ?? 0.10);
        minuteScores[m] += sideSign * w;
        break;
      case MatchEventKind.card:
        minuteScores[m] += sideSign * -EngineParams.momentumCardPenalty; // side is offending side as -1 or +1 context-dependent
        break;
      case MatchEventKind.injury:
        minuteScores[m] += sideSign * -EngineParams.momentumInjuryPenalty;
        break;
      case MatchEventKind.info:
        // no change
        break;
    }
  }
  return minuteScores;
}
