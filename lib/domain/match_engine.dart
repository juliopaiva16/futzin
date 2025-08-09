import 'dart:async';
import 'dart:math';

import 'entities.dart';
import 'messages.dart';
import 'graph_engine.dart';

part 'match_engine_types.dart';
part 'match_engine_sequences.dart';

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
  MatchEngine(this.teamA, this.teamB, {required this.messages, int? seed, this.useGraph = false})
      : rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

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
    final eventChance = 0.28 + 0.27 * tempoAvg; // 0.28..0.55
    if (rng.nextDouble() > eventChance) {
      possA += 30.0; possB += 30.0;
      _controller.add(MatchEvent(minute, messages.calmMinute(minute), scoreA, scoreB, xgA, xgB));
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
    final secs = (20 + 4 * seq.length).clamp(20, 60).toDouble();
    const atkShare = 0.65;
    if (attackingTeamA) {
      possA += secs * atkShare; possB += secs * (1 - atkShare);
    } else {
      possB += secs * atkShare; possA += secs * (1 - atkShare);
    }
    for (final ev in seq) {
      switch (ev.type) {
        case _SeqType.text:
          _controller.add(MatchEvent(minute, "$minute': ${ev.text}", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.info, side: attackingTeamA ? 1 : -1));
          break;
        case _SeqType.shot:
          final sxg = ev.xg ?? 0.10;
          _controller.add(MatchEvent(minute, "$minute': ${ev.text} (xG ${sxg.toStringAsFixed(2)})", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.shot, side: attackingTeamA ? 1 : -1, shotXg: sxg));
          break;
        case _SeqType.goal:
          final shotXg = ev.xg ?? 0.1;
          if (attackingTeamA) { scoreA++; xgA += shotXg; } else { scoreB++; xgB += shotXg; }
          final suffix = ev.xg != null ? " (xG ${shotXg.toStringAsFixed(2)})" : "";
          _controller.add(MatchEvent(minute, "$minute': ${ev.text}$suffix", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.goal, side: attackingTeamA ? 1 : -1, shotXg: shotXg));
          break;
        case _SeqType.card:
          final offender = ev.offender!; final color = ev.cardType == _CardType.red ? CardColor.red : CardColor.yellow;
          _controller.add(MatchEvent(minute, "$minute': ${ev.text}", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.card, side: attackingTeamA ? -1 : 1, cardColor: color));
          if (ev.cardType == _CardType.red) {
            offender.sentOff = true; teamA.selectedIds.remove(offender.id); teamB.selectedIds.remove(offender.id);
          } else if (ev.cardType == _CardType.yellow) {
            offender.yellowCards += 1; if (offender.yellowCards >= 2) { offender.sentOff = true; teamA.selectedIds.remove(offender.id); teamB.selectedIds.remove(offender.id);
              _controller.add(MatchEvent(minute, "$minute': ${messages.secondYellow(offender.name)}", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.card, side: attackingTeamA ? -1 : 1, cardColor: CardColor.red)); }
          }
          break;
        case _SeqType.injury:
          _controller.add(MatchEvent(minute, "$minute': ${ev.text}", scoreA, scoreB, xgA, xgB, kind: MatchEventKind.injury, side: attackingTeamA ? 1 : -1));
          final p = ev.injuredPlayer; if (p != null) { p.injured = true; teamA.selectedIds.remove(p.id); teamB.selectedIds.remove(p.id); }
          break;
      }
    }
    return false;
  }

  void _tick(Timer _) { if (advanceMinute()) stop(); }

  void _applyFatigue(TeamConfig t) {
    for (final p in t.selected) {
      if (p.sentOff || p.injured) continue;
      final base = 0.10; // per minute
      final tempo = t.tactics.tempo;
      final pressing = t.tactics.pressing;
      final fatigue = base + 0.35 * tempo + 0.25 * pressing;
      p.currentStamina = (p.currentStamina - fatigue * 100 / 90).clamp(0, 100);
    }
  }

  _TeamRatings _teamRatings(TeamConfig t) {
    double eff(int base, double sta) => base * (0.60 + 0.40 * (sta / 100.0));
    final gk = t.selected.where((p) => p.pos == Position.GK && !p.sentOff && !p.injured).toList();
    final defs = t.selected.where((p) => p.pos == Position.DEF && !p.sentOff && !p.injured).toList();
    final mids = t.selected.where((p) => p.pos == Position.MID && !p.sentOff && !p.injured).toList();
    final fwds = t.selected.where((p) => p.pos == Position.FWD && !p.sentOff && !p.injured).toList();
    double avg(List<double> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;
    final gkD = gk.isNotEmpty ? eff(gk.first.defense, gk.first.currentStamina) : 40.0;
    final defD = avg(defs.map((p) => eff(p.defense, p.currentStamina)).toList());
    final defA = avg(defs.map((p) => eff(p.attack, p.currentStamina)).toList());
    final midD = avg(mids.map((p) => eff(p.defense, p.currentStamina)).toList());
    final midA = avg(mids.map((p) => eff(p.attack, p.currentStamina)).toList());
    final fwdA = avg(fwds.map((p) => eff(p.attack, p.currentStamina)).toList());
    final fwdD = avg(fwds.map((p) => eff(p.defense, p.currentStamina)).toList());
    double attack = fwdA * 1.0 + midA * 0.65 + defA * 0.2;
    double defense = defD * 1.0 + midD * 0.55 + gkD * 1.2 + fwdD * 0.1;
    final bias = t.tactics.attackBias; final pressing = t.tactics.pressing; final line = t.tactics.lineHeight; final width = t.tactics.width;
    attack *= (1.0 + 0.17 * bias + 0.05 * width);
    defense *= (1.0 - 0.11 * bias + 0.08 * (1.0 - width));
    defense += pressing * 6.0;
    attack *= (1.0 + 0.06 * line);
    defense *= (1.0 - 0.06 * line);
    return _TeamRatings(attackAdj: attack, defenseAdj: defense, gk: gk.isNotEmpty ? gk.first : null);
  }
}
