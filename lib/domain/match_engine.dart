// Match simulation engine.
//
// Emits [MatchEvent]s on a stream while simulating a football match minute by minute.

import 'dart:async';
import 'dart:math';

import 'entities.dart';
import 'messages.dart';

enum MatchEventKind { info, shot, goal, card, injury }

enum CardColor { yellow, red }

class MatchEvent {
  final int minute;
  final String text;
  final int scoreA;
  final int scoreB;
  final double xgA;
  final double xgB;
  // Extra fields for momentum visualization
  final MatchEventKind kind; // info by default
  // side: +1 -> Team A, -1 -> Team B, 0 -> neutral/info
  final int side;
  final double? shotXg; // for shots/goals
  final CardColor? cardColor;
  MatchEvent(
    this.minute,
    this.text,
    this.scoreA,
    this.scoreB,
    this.xgA,
    this.xgB, {
    this.kind = MatchEventKind.info,
    this.side = 0,
    this.shotXg,
    this.cardColor,
  });
}

class _TeamRatings {
  final double attackAdj;
  final double defenseAdj;
  final Player? gk;
  _TeamRatings({
    required this.attackAdj,
    required this.defenseAdj,
    required this.gk,
  });
}

enum _SeqType { text, shot, goal, card, injury }

enum _CardType { yellow, red }

class _SeqEvent {
  final _SeqType type;
  final String text;
  final double? xg; // for shots
  final Player? offender;
  final _CardType? cardType;
  final Player? injuredPlayer;
  _SeqEvent._(
    this.type,
    this.text, {
    this.xg,
    this.offender,
    this.cardType,
    this.injuredPlayer,
  });
  factory _SeqEvent.text(String t) => _SeqEvent._(_SeqType.text, t);
  factory _SeqEvent.shot(double xg, String t) =>
      _SeqEvent._(_SeqType.shot, t, xg: xg);
  factory _SeqEvent.goal(String t, double xg) =>
      _SeqEvent._(_SeqType.goal, t, xg: xg);
  factory _SeqEvent.card(String t, Player offender, _CardType type) =>
      _SeqEvent._(_SeqType.card, t, offender: offender, cardType: type);
  factory _SeqEvent.injury(String t, Player p) =>
      _SeqEvent._(_SeqType.injury, t, injuredPlayer: p);
}

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
  double possA = 0.0; // seconds
  double possB = 0.0; // seconds
  bool isRunning = false;

  // Real-time speed control (1x default)
  static const int _baseTickMs = 450;
  double speedMultiplier = 1.0;

  MatchEngine(this.teamA, this.teamB, {required this.messages, int? seed})
    : rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  Stream<MatchEvent> get stream => _controller.stream;

  void _startTimer() {
    _timer?.cancel();
    final ms = (_baseTickMs / speedMultiplier).clamp(20, 2000).round();
    _timer = Timer.periodic(Duration(milliseconds: ms), _tick);
  }

  void setSpeed(double multiplier) {
    speedMultiplier = multiplier.clamp(0.25, 10.0);
    if (isRunning) {
      _startTimer();
    }
  }

  void start() {
    if (isRunning) return;
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
    _controller.add(
      MatchEvent(minute, messages.kickoff(), scoreA, scoreB, xgA, xgB),
    );
    _startTimer();
  }

  void stop() {
    isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

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
    double eff(int base, double sta) {
      return base * (0.60 + 0.40 * (sta / 100.0));
    }

    final gk = t.selected
        .where((p) => p.pos == Position.GK && !p.sentOff && !p.injured)
        .toList();
    final defs = t.selected
        .where((p) => p.pos == Position.DEF && !p.sentOff && !p.injured)
        .toList();
    final mids = t.selected
        .where((p) => p.pos == Position.MID && !p.sentOff && !p.injured)
        .toList();
    final fwds = t.selected
        .where((p) => p.pos == Position.FWD && !p.sentOff && !p.injured)
        .toList();

    double avg(List<double> xs) =>
        xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;

    final gkD = gk.isNotEmpty
        ? eff(gk.first.defense, gk.first.currentStamina)
        : 40.0;
    final defD = avg(
      defs.map((p) => eff(p.defense, p.currentStamina)).toList(),
    );
    final defA = avg(defs.map((p) => eff(p.attack, p.currentStamina)).toList());
    final midD = avg(
      mids.map((p) => eff(p.defense, p.currentStamina)).toList(),
    );
    final midA = avg(mids.map((p) => eff(p.attack, p.currentStamina)).toList());
    final fwdA = avg(fwds.map((p) => eff(p.attack, p.currentStamina)).toList());
    final fwdD = avg(
      fwds.map((p) => eff(p.defense, p.currentStamina)).toList(),
    );

    double attack = fwdA * 1.0 + midA * 0.65 + defA * 0.2;
    double defense = defD * 1.0 + midD * 0.55 + gkD * 1.2 + fwdD * 0.1;

    final bias = t.tactics.attackBias; // -1..+1
    final pressing = t.tactics.pressing; // 0..1
    final line = t.tactics.lineHeight; // 0..1
    final width = t.tactics.width; // 0..1

    attack *= (1.0 + 0.17 * bias + 0.05 * width);
    defense *= (1.0 - 0.11 * bias + 0.08 * (1.0 - width));
    defense += pressing * 6.0;
    attack *= (1.0 + 0.06 * line);
    defense *= (1.0 - 0.06 * line);

    return _TeamRatings(
      attackAdj: attack,
      defenseAdj: defense,
      gk: gk.isNotEmpty ? gk.first : null,
    );
  }

  void _tick(Timer tmr) {
    minute++;
    if (minute > 90) {
      _controller.add(
        MatchEvent(minute, messages.endMatch(), scoreA, scoreB, xgA, xgB),
      );
      stop();
      return;
    }

    _applyFatigue(teamA);
    _applyFatigue(teamB);

    final tempoAvg = (teamA.tactics.tempo + teamB.tactics.tempo) / 2.0;
    final eventChance = 0.28 + 0.27 * tempoAvg; // 0.28..0.55

    if (rng.nextDouble() > eventChance) {
      // Calm minute: assume split possession
      possA += 30.0;
      possB += 30.0;
      _controller.add(
        MatchEvent(
          minute,
          messages.calmMinute(minute),
          scoreA,
          scoreB,
          xgA,
          xgB,
        ),
      );
      return;
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

    final seq = _buildAttackSequence(atkTeam, defTeam, atkRat, defRat);

    // Possession attribution for this minute (single time per minute)
    final secs = (20 + 4 * seq.length).clamp(20, 60).toDouble();
    final atkShare = 0.65; // attacker tends to keep more of the minute
    if (attackingTeamA) {
      possA += secs * atkShare;
      possB += secs * (1 - atkShare);
    } else {
      possB += secs * atkShare;
      possA += secs * (1 - atkShare);
    }

    for (final ev in seq) {
      if (ev.type == _SeqType.text) {
        _controller.add(
          MatchEvent(
            minute,
            "$minute': ${ev.text}",
            scoreA,
            scoreB,
            xgA,
            xgB,
            kind: MatchEventKind.info,
            side: attackingTeamA ? 1 : -1,
          ),
        );
      } else if (ev.type == _SeqType.shot) {
        final sxg = ev.xg ?? 0.10;
        _controller.add(
          MatchEvent(
            minute,
            "$minute': ${ev.text} (xG ${sxg.toStringAsFixed(2)})",
            scoreA,
            scoreB,
            xgA,
            xgB,
            kind: MatchEventKind.shot,
            side: attackingTeamA ? 1 : -1,
            shotXg: sxg,
          ),
        );
      } else if (ev.type == _SeqType.goal) {
        final shotXg = ev.xg ?? 0.1;
        if (attackingTeamA) {
          scoreA++;
          xgA += shotXg;
        } else {
          scoreB++;
          xgB += shotXg;
        }
        final suffix = ev.xg != null ? " (xG ${shotXg.toStringAsFixed(2)})" : "";
        _controller.add(
          MatchEvent(
            minute,
            "$minute': ${ev.text}$suffix",
            scoreA,
            scoreB,
            xgA,
            xgB,
            kind: MatchEventKind.goal,
            side: attackingTeamA ? 1 : -1,
            shotXg: shotXg,
          ),
        );
      } else if (ev.type == _SeqType.card) {
        final offender = ev.offender!;
        final color = ev.cardType == _CardType.red ? CardColor.red : CardColor.yellow;
        _controller.add(
          MatchEvent(
            minute,
            "$minute': ${ev.text}",
            scoreA,
            scoreB,
            xgA,
            xgB,
            kind: MatchEventKind.card,
            side: attackingTeamA ? -1 : 1, // card belongs to defending side
            cardColor: color,
          ),
        );
        if (ev.cardType == _CardType.red) {
          offender.sentOff = true;
          if (teamA.selectedIds.contains(offender.id)) {
            teamA.selectedIds.remove(offender.id);
          }
          if (teamB.selectedIds.contains(offender.id)) {
            teamB.selectedIds.remove(offender.id);
          }
        } else if (ev.cardType == _CardType.yellow) {
          offender.yellowCards += 1;
          if (offender.yellowCards >= 2) {
            offender.sentOff = true;
            if (teamA.selectedIds.contains(offender.id)) {
              teamA.selectedIds.remove(offender.id);
            }
            if (teamB.selectedIds.contains(offender.id)) {
              teamB.selectedIds.remove(offender.id);
            }
            _controller.add(
              MatchEvent(
                minute,
                "$minute': ${messages.secondYellow(offender.name)}",
                scoreA,
                scoreB,
                xgA,
                xgB,
                kind: MatchEventKind.card,
                side: attackingTeamA ? -1 : 1,
                cardColor: CardColor.red,
              ),
            );
          }
        }
      } else if (ev.type == _SeqType.injury) {
        _controller.add(
          MatchEvent(
            minute,
            "$minute': ${ev.text}",
            scoreA,
            scoreB,
            xgA,
            xgB,
            kind: MatchEventKind.injury,
            side: attackingTeamA ? 1 : -1,
          ),
        );
        final p = ev.injuredPlayer;
        if (p != null) {
          p.injured = true;
          if (teamA.selectedIds.contains(p.id)) {
            teamA.selectedIds.remove(p.id);
          }
          if (teamB.selectedIds.contains(p.id)) {
            teamB.selectedIds.remove(p.id);
          }
        }
      }
    }
  }

  List<_SeqEvent> _buildAttackSequence(
    TeamConfig atk,
    TeamConfig def,
    _TeamRatings atkRat,
    _TeamRatings defRat,
  ) {
    // Short, localized attacking sequence with passes, possible foul/card, and a shot outcome.
    final seq = <_SeqEvent>[];

    List<Player> alive(TeamConfig t) =>
        t.selected.where((p) => !p.sentOff && !p.injured).toList();
    final atkAlive = alive(atk);
    final defAlive = alive(def);
    if (atkAlive.isEmpty || defAlive.isEmpty) {
      seq.add(_SeqEvent.text(messages.defenseCloses(def.name)));
      return seq;
    }

    Player pickAttacker({Player? exclude}) {
      final pool = atkAlive.where((p) => p != exclude).toList();
      if (pool.isEmpty) return atkAlive.first;
      // Weight: FWD 3x, MID 2x, DEF 1x
      final weighted = <Player>[];
      for (final p in pool) {
        int w = p.pos == Position.FWD
            ? 3
            : p.pos == Position.MID
                ? 2
                : 1;
        for (int i = 0; i < w; i++) {
          weighted.add(p);
        }
      }
      return weighted[rng.nextInt(weighted.length)];
    }

    Player pickDefender() {
      final pool = defAlive.isEmpty ? def.selected : defAlive;
      // Prefer DEF, then MID
      final defs = pool.where((p) => p.pos == Position.DEF).toList();
      if (defs.isNotEmpty) return defs[rng.nextInt(defs.length)];
      final mids = pool.where((p) => p.pos == Position.MID).toList();
      if (mids.isNotEmpty) return mids[rng.nextInt(mids.length)];
      return pool[rng.nextInt(pool.length)];
    }

    // Start: ball carrier finds space
    var carrier = pickAttacker();
    seq.add(_SeqEvent.text(messages.findsSpace(carrier.name)));

    // Chance the defense shuts it down immediately
    final closeChance =
        0.10 +
        0.25 * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj));
    if (rng.nextDouble() < closeChance) {
      seq.add(_SeqEvent.text(messages.defenseCloses(def.name)));
      return seq;
    }

    // 0-2 quick passes depending on tempo and pressure
    final passBase =
        1 + ((atk.tactics.tempo + atk.tactics.width) * 1.2).round();
    final passCount = max(0, min(2, passBase + rng.nextInt(2) - 1));

    for (int i = 0; i < passCount; i++) {
      // Interception chance before the pass goes through
      final interceptChance =
          0.14 +
          0.20 * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj));
      if (rng.nextDouble() < interceptChance) {
        final interceptor = pickDefender();
        seq.add(
          _SeqEvent.text(messages.intercepted(interceptor.name, def.name)),
        );
        return seq;
      }

      final receiver = pickAttacker(exclude: carrier);
      seq.add(_SeqEvent.text(messages.pass(carrier.name, receiver.name)));
      carrier = receiver;

      // Occasional late foul during buildup
      final foulChance = 0.06 + 0.04 * def.tactics.pressing;
      if (rng.nextDouble() < foulChance) {
        final offender = pickDefender();
        seq.add(_SeqEvent.text(messages.lateFoul(def.name)));
        // Card severity
        final redProb = 0.04 + 0.03 * atk.tactics.tempo;
        if (rng.nextDouble() < redProb) {
          seq.add(
            _SeqEvent.card(
              messages.foulRed(offender.name, def.name),
              offender,
              _CardType.red,
            ),
          );
        } else {
          seq.add(
            _SeqEvent.card(
              messages.foulYellow(offender.name, def.name),
              offender,
              _CardType.yellow,
            ),
          );
          // Rare second yellow immediately (simulate persistent fouling)
          if (offender.yellowCards == 1 && rng.nextDouble() < 0.05) {
            // Represent as another yellow leading to second yellow via tick handler
            seq.add(
              _SeqEvent.card(
                messages.foulYellow(offender.name, def.name),
                offender,
                _CardType.yellow,
              ),
            );
          }
        }
        // Injury to carrier sometimes
        if (rng.nextDouble() < 0.12) {
          seq.add(_SeqEvent.text(messages.injuryAfterChallenge(carrier.name)));
          seq.add(
            _SeqEvent.injury(
              messages.injuryOutside(carrier.name, atk.name),
              carrier,
            ),
          );
        }
        return seq;
      }
    }

    // Shot phase
    seq.add(_SeqEvent.text(messages.shoots(carrier.name)));

    // Compute shot quality (xG proxy)
    final quality =
        atkRat.attackAdj / (atkRat.attackAdj + defRat.defenseAdj + 1e-6);
    double xg = 0.05 + 0.45 * quality + (rng.nextDouble() * 0.10 - 0.05);
    xg = xg.clamp(0.03, 0.65);

    final gkSave = ((defRat.gk?.defense ?? 55) / 100.0);
    double pGoal = (xg * (0.95 - 0.35 * gkSave)).clamp(0.02, 0.80);

    final r = rng.nextDouble();
    if (r < pGoal) {
      seq.add(_SeqEvent.goal(messages.goal(atk.name, carrier.name), xg));
      return seq;
    }

    // Register a shot (non-goal)
    seq.add(_SeqEvent.shot(xg, 'Shot'));

    // Non-goal outcomes: save or off target
    final pSave =
        0.55 -
        0.20 * quality +
        0.25 * gkSave; // more saves if strong GK / low quality
    if (rng.nextDouble() < pSave) {
      seq.add(_SeqEvent.text(messages.savedByKeeper()));
    } else {
      if (rng.nextDouble() < 0.20) {
        seq.add(_SeqEvent.text(messages.deflectedOut()));
      } else {
        seq.add(_SeqEvent.text(messages.offTarget()));
      }
    }

    return seq;
  }
}
