import 'dart:async';
import 'dart:math';

import 'entities.dart';
import 'messages.dart';
import 'graph_engine.dart';
import 'engine_params.dart';
import 'graph_logging.dart';

part 'match_engine_types.dart';
part 'match_engine_sequences.dart';
part 'match_engine_utils.dart';

class MatchEngine {
  final TeamConfig teamA;
  final TeamConfig teamB;
  final MatchMessages messages;
  final Random rng;
  final StreamController<MatchEvent> _controller = StreamController.broadcast();
  Timer? _timer;
  int minute = 0;
  int scoreA = 0;
  int scoreB = 0;
  double xgA = 0.0;
  double xgB = 0.0;
  double possA = 0.0;
  double possB = 0.0;
  bool isRunning = false;
  static const int _baseTickMs = 450;
  double speedMultiplier = 1.0;
  final bool useGraph; // experimental graph micro-engine (fase 2)
  final GraphEventLogger? graphLogger; // MT1 logger (nullable)
  final String matchId; // unique ID for instrumentation
  int _possessionCounter = 0;
  MatchEngine(this.teamA, this.teamB, {required this.messages, int? seed, this.useGraph = false, this.graphLogger, String? matchId})
      : matchId = matchId ?? 'M${DateTime.now().millisecondsSinceEpoch % 1000000}',
        rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  Stream<MatchEvent> get stream => _controller.stream;

  // Timer control
  void _startTimer() {
    _timer?.cancel();
    final ms = (_baseTickMs / speedMultiplier).clamp(20, 2000).round();
    _timer = Timer.periodic(Duration(milliseconds: ms), _tick);
  }
  void setSpeed(double multiplier) {
    speedMultiplier = multiplier.clamp(0.25, 10.0);
    if (isRunning) _startTimer();
  }
  void stop() {
    isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  // Init common
  void _initMatch() {
    isRunning = true;
    minute = 0;
    scoreA = 0;
    scoreB = 0;
    xgA = 0;
    xgB = 0;
    possA = 0;
    possB = 0;
    teamA.resetRuntime();
    teamB.resetRuntime();
    _controller.add(MatchEvent(0, messages.kickoff(), scoreA, scoreB, xgA, xgB));
  }

  // ========== Graph Instrumentation Helpers (MT1) ==========
  int _startPossession() => ++_possessionCounter;
  void _logGraphAction({
    required int minute,
    required int possessionId,
    required int actionIndex,
    required String actionType,
    required bool teamAAction,
    required Player from,
    Player? to,
    double? preXg,
    double? xgDelta,
    bool isShot = false,
    bool isGoal = false,
    double? passDist,
    double? pressureScore,
  }) {
    if (graphLogger == null || EngineParams.graphLoggingMode == 0) return;
    graphLogger!.log(GraphActionLog(
      matchId: matchId,
      minute: minute,
      possessionId: possessionId,
      actionIndex: actionIndex,
      actionType: actionType,
      side: teamAAction ? 'A' : 'B',
      fromPlayerId: from.id,
      toPlayerId: to?.id,
      fromX: from.x,
      fromY: from.y,
      toX: to?.x,
      toY: to?.y,
      preXg: preXg,
      xgDelta: xgDelta,
      isShot: isShot,
      isGoal: isGoal,
      passDist: passDist,
      pressureScore: pressureScore,
    ));
  }

  // Public start variants
  void start() { if (isRunning) return; _initMatch(); _startTimer(); }
  void startManual() { if (isRunning) return; _initMatch(); }

  // Manual minute advance
  bool advanceMinute() {
    if (!isRunning) return true;
    minute++;
    if (minute > 90) {
      _controller.add(MatchEvent(minute, messages.endMatch(), scoreA, scoreB, xgA, xgB));
      isRunning = false;
      return true;
    }
    _applyFatigue(teamA);
    _applyFatigue(teamB);
    final tempoAvg = (teamA.tactics.tempo + teamB.tactics.tempo) / 2.0;
    final eventChance = EngineParams.legacyBaseEventChance + EngineParams.legacyTempoEventFactor * tempoAvg; // 0.28..0.55
    if (rng.nextDouble() > eventChance) {
      possA += EngineParams.legacyCalmPossSeconds; possB += EngineParams.legacyCalmPossSeconds;
  _controller.add(MatchEvent(minute, messages.calmMinute(minute), scoreA, scoreB, xgA, xgB, momentumDelta: 0));
      return false;
    }
    final aRating = _teamRatings(teamA);
    final bRating = _teamRatings(teamB);
    final aAttackVsB = aRating.attackAdj / max(1.0, bRating.defenseAdj);
    final bAttackVsA = bRating.attackAdj / max(1.0, aRating.defenseAdj);
    final pA = aAttackVsB / (aAttackVsB + bAttackVsA);
    final attackingTeamA = rng.nextDouble() < pA;
    final atkTeam = attackingTeamA ? teamA : teamB;
    final defTeam = attackingTeamA ? teamB : teamA;
    final atkRat = attackingTeamA ? aRating : bRating;
    final defRat = attackingTeamA ? bRating : aRating;
    final seq = useGraph
        ? _buildGraphAttackSequence(this, atkTeam, defTeam, atkRat, defRat, attackingTeamA)
        : _buildAttackSequence(this, atkTeam, defTeam, atkRat, defRat);
    final secs = (EngineParams.legacySeqMinSeconds + EngineParams.legacySeqPerSubEventSeconds * seq.length)
        .clamp(EngineParams.legacySeqMinSeconds, EngineParams.legacySeqMaxSeconds)
        .toDouble();
    const atkShare = EngineParams.legacySeqPossShare;
    if (attackingTeamA) {
      possA += secs * atkShare; possB += secs * (1 - atkShare);
    } else {
      possB += secs * atkShare; possA += secs * (1 - atkShare);
    }
    for (final ev in seq) {
      switch (ev.type) {
        case _SeqType.text:
          _controller.add(MatchEvent(minute, "$minute': ${ev.text}", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.info, side: attackingTeamA ? 1 : -1, momentumDelta: 0));
          break;
        case _SeqType.shot:
          final sxg = ev.xg ?? 0.10;
          final mom = (attackingTeamA ? 1.0 : -1.0) * (EngineParams.momentumShotBase + EngineParams.momentumShotXgScale * sxg);
          _controller.add(MatchEvent(minute, "$minute': ${ev.text} (xG ${sxg.toStringAsFixed(2)})", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.shot, side: attackingTeamA ? 1 : -1, shotXg: sxg, momentumDelta: mom));
          break;
        case _SeqType.goal:
          final shotXg = ev.xg ?? 0.1;
          if (attackingTeamA) { scoreA++; xgA += shotXg; } else { scoreB++; xgB += shotXg; }
          final suffix = ev.xg != null ? " (xG ${shotXg.toStringAsFixed(2)})" : "";
          final mom = (attackingTeamA ? 1.0 : -1.0) * EngineParams.momentumGoal;
          _controller.add(MatchEvent(minute, "$minute': ${ev.text}$suffix", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.goal, side: attackingTeamA ? 1 : -1, shotXg: shotXg, momentumDelta: mom));
          break;
        case _SeqType.card:
          final offender = ev.offender!; final color = ev.cardType == _CardType.red ? CardColor.red : CardColor.yellow;
          final mom = (attackingTeamA ? -1.0 : 1.0) * EngineParams.momentumCardPenalty; // small negative to offending side
          _controller.add(MatchEvent(minute, "$minute': ${ev.text}", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.card, side: attackingTeamA ? -1 : 1, cardColor: color, momentumDelta: mom));
          if (ev.cardType == _CardType.red) {
            offender.sentOff = true; teamA.selectedIds.remove(offender.id); teamB.selectedIds.remove(offender.id);
          } else if (ev.cardType == _CardType.yellow) {
            offender.yellowCards += 1; if (offender.yellowCards >= 2) { offender.sentOff = true; teamA.selectedIds.remove(offender.id); teamB.selectedIds.remove(offender.id);
              _controller.add(MatchEvent(minute, "$minute': ${messages.secondYellow(offender.name)}", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.card, side: attackingTeamA ? -1 : 1, cardColor: CardColor.red)); }
          }
          break;
        case _SeqType.injury:
          final mom = (attackingTeamA ? -1.0 : 1.0) * EngineParams.momentumInjuryPenalty; // slight negative to side suffering the injury context
          _controller.add(MatchEvent(minute, "$minute': ${ev.text}", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.injury, side: attackingTeamA ? 1 : -1, momentumDelta: mom));
          final p = ev.injuredPlayer; if (p != null) { p.injured = true; teamA.selectedIds.remove(p.id); teamB.selectedIds.remove(p.id); }
          break;
      }
    }
    return false;
  }

  void _tick(Timer _) { if (advanceMinute()) stop(); }
}
