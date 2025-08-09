part of 'match_engine.dart';

// Legacy attacking sequence builder
List<_SeqEvent> _buildAttackSequence(
  MatchEngine eng,
  TeamConfig atk,
  TeamConfig def,
  _TeamRatings atkRat,
  _TeamRatings defRat,
) {
  final rng = eng.rng;
  final messages = eng.messages;
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
    final defs = pool.where((p) => p.pos == Position.DEF).toList();
    if (defs.isNotEmpty) return defs[rng.nextInt(defs.length)];
    final mids = pool.where((p) => p.pos == Position.MID).toList();
    if (mids.isNotEmpty) return mids[rng.nextInt(mids.length)];
    return pool[rng.nextInt(pool.length)];
  }

  var carrier = pickAttacker();
  seq.add(_SeqEvent.text(messages.findsSpace(carrier.name)));
  final closeChance =
      0.10 + 0.25 * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj));
  if (rng.nextDouble() < closeChance) {
    seq.add(_SeqEvent.text(messages.defenseCloses(def.name)));
    return seq;
  }
  final passBase = 1 + ((atk.tactics.tempo + atk.tactics.width) * 1.2).round();
  final passCount = max(0, min(2, passBase + rng.nextInt(2) - 1));
  for (int i = 0; i < passCount; i++) {
    final interceptChance = 0.14 +
        0.20 * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj));
    if (rng.nextDouble() < interceptChance) {
      final interceptor = pickDefender();
      seq.add(_SeqEvent.text(messages.intercepted(interceptor.name, def.name)));
      return seq;
    }
    final receiver = pickAttacker(exclude: carrier);
    seq.add(_SeqEvent.text(messages.pass(carrier.name, receiver.name)));
    carrier = receiver;
    final foulChance = 0.06 + 0.04 * def.tactics.pressing;
    if (rng.nextDouble() < foulChance) {
      final offender = pickDefender();
      seq.add(_SeqEvent.text(messages.lateFoul(def.name)));
      final redProb = 0.04 + 0.03 * atk.tactics.tempo;
      if (rng.nextDouble() < redProb) {
        seq.add(_SeqEvent.card(messages.foulRed(offender.name, def.name), offender,
            _CardType.red));
      } else {
        seq.add(_SeqEvent.card(messages.foulYellow(offender.name, def.name),
            offender, _CardType.yellow));
        if (offender.yellowCards == 1 && rng.nextDouble() < 0.05) {
          seq.add(_SeqEvent.card(messages.foulYellow(offender.name, def.name),
              offender, _CardType.yellow));
        }
      }
      if (rng.nextDouble() < 0.12) {
        seq.add(_SeqEvent.text(messages.injuryAfterChallenge(carrier.name)));
        seq.add(_SeqEvent.injury(
            messages.injuryOutside(carrier.name, atk.name), carrier));
      }
      return seq;
    }
  }
  seq.add(_SeqEvent.text(messages.shoots(carrier.name)));
  final quality = atkRat.attackAdj / (atkRat.attackAdj + defRat.defenseAdj + 1e-6);
  double xg = 0.05 + 0.45 * quality + (rng.nextDouble() * 0.10 - 0.05);
  xg = xg.clamp(0.03, 0.65);
  final gkSave = ((defRat.gk?.defense ?? 55) / 100.0);
  double pGoal = (xg * (0.95 - 0.35 * gkSave)).clamp(0.02, 0.80);
  if (rng.nextDouble() < pGoal) {
    seq.add(_SeqEvent.goal(messages.goal(atk.name, carrier.name), xg));
    return seq;
  }
  seq.add(_SeqEvent.shot(xg, 'Shot'));
  final pSave = 0.55 - 0.20 * quality + 0.25 * gkSave;
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

// Graph experimental short-pass + shot sequence
List<_SeqEvent> _buildGraphAttackSequence(
  MatchEngine eng,
  TeamConfig atk,
  TeamConfig def,
  _TeamRatings atkRat,
  _TeamRatings defRat,
  bool attackingTeamA,
) {
  final rng = eng.rng;
  final messages = eng.messages;
  final teamA = eng.teamA;
  final teamB = eng.teamB;
  final seq = <_SeqEvent>[];
  List<Player> alive(TeamConfig t) =>
      t.selected.where((p) => !p.sentOff && !p.injured).toList();
  final atkAlive = alive(atk);
  final defAlive = alive(def);
  if (atkAlive.isEmpty || defAlive.isEmpty) {
    seq.add(_SeqEvent.text(messages.defenseCloses(def.name)));
    return seq;
  }
  if (atkAlive.any((p) => p.x == null || p.y == null) ||
      defAlive.any((p) => p.x == null || p.y == null)) {
    GraphLayout.assignMatchCoordinates(teamA, teamB);
  }
  Player pickStarter() {
    final fw = atkAlive.where((p) => p.pos == Position.FWD).toList();
    if (fw.isNotEmpty) return fw[rng.nextInt(fw.length)];
    final md = atkAlive.where((p) => p.pos == Position.MID).toList();
    if (md.isNotEmpty) return md[rng.nextInt(md.length)];
    return atkAlive[rng.nextInt(atkAlive.length)];
  }

  double dist(Player a, Player b) {
    final dx = (a.x ?? 0.5) - (b.x ?? 0.5);
    final dy = (a.y ?? 0.5) - (b.y ?? 0.5);
    return sqrt(dx * dx + dy * dy);
  }

  List<Player> receiversFor(Player from) {
    final list = <Player>[];
    for (final p in atkAlive) {
      if (p == from) continue;
      final d = dist(from, p);
      if (d <= 0.55) list.add(p);
    }
    return list.isEmpty ? atkAlive.where((p) => p != from).toList() : list;
  }

  Player pickPass(Player from) {
    final recs = receiversFor(from);
    if (recs.isEmpty) return from;
    final weights = recs.map((p) {
      final d = dist(from, p).clamp(0.02, 1.0);
      return 1.0 / (0.08 + d);
    }).toList();
    final sum = weights.reduce((a, b) => a + b);
    double r = rng.nextDouble() * sum;
    for (int i = 0; i < recs.length; i++) {
      r -= weights[i];
      if (r <= 0) return recs[i];
    }
    return recs.last;
  }

  Player pickDefender() {
    final pool = defAlive;
    final defs = pool.where((p) => p.pos == Position.DEF).toList();
    if (defs.isNotEmpty) return defs[rng.nextInt(defs.length)];
    final mids = pool.where((p) => p.pos == Position.MID).toList();
    if (mids.isNotEmpty) return mids[rng.nextInt(mids.length)];
    return pool[rng.nextInt(pool.length)];
  }

  var carrier = pickStarter();
  seq.add(_SeqEvent.text(messages.findsSpace(carrier.name)));
  final closeChance =
      0.08 + 0.22 * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj));
  if (rng.nextDouble() < closeChance) {
    seq.add(_SeqEvent.text(messages.defenseCloses(def.name)));
    return seq;
  }
  final maxPassesBase = 1 + ((atk.tactics.tempo + atk.tactics.width) * 1.1).round();
  final maxPasses = max(1, min(3, maxPassesBase));
  for (int i = 0; i < maxPasses; i++) {
    final interceptBase = 0.10 +
        0.18 * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj)) +
        0.05 * def.tactics.pressing;
    final rec = pickPass(carrier);
    final d = dist(carrier, rec).clamp(0.05, 1.0);
    final interceptChance = (interceptBase + 0.15 * (d - 0.15)).clamp(0.02, 0.65);
    if (rng.nextDouble() < interceptChance) {
      final interceptor = pickDefender();
      seq.add(_SeqEvent.text(messages.intercepted(interceptor.name, def.name)));
      return seq;
    }
    seq.add(_SeqEvent.text(messages.pass(carrier.name, rec.name)));
    carrier = rec;
    final foulChance = 0.05 + 0.05 * def.tactics.pressing;
    if (rng.nextDouble() < foulChance) {
      final offender = pickDefender();
      seq.add(_SeqEvent.text(messages.lateFoul(def.name)));
      final redProb = 0.03 + 0.03 * atk.tactics.tempo;
      if (rng.nextDouble() < redProb) {
        seq.add(_SeqEvent.card(messages.foulRed(offender.name, def.name), offender,
            _CardType.red));
      } else {
        seq.add(_SeqEvent.card(messages.foulYellow(offender.name, def.name),
            offender, _CardType.yellow));
      }
      return seq;
    }
  }
  seq.add(_SeqEvent.text(messages.shoots(carrier.name)));
  final goalX = attackingTeamA ? 1.0 : 0.0;
  final dxGoal = (goalX - (carrier.x ?? 0.5)).abs().clamp(0.0, 1.0);
  final baseQual = atkRat.attackAdj / (atkRat.attackAdj + defRat.defenseAdj + 1e-6);
  final posFactor = (1.0 - dxGoal);
  double xg = 0.04 + 0.42 * (0.55 * baseQual + 0.45 * posFactor) +
      (rng.nextDouble() * 0.08 - 0.04);
  xg = xg.clamp(0.02, 0.60);
  final gkSave = ((defRat.gk?.defense ?? 55) / 100.0);
  double pGoal = (xg * (0.95 - 0.33 * gkSave)).clamp(0.02, 0.78);
  if (rng.nextDouble() < pGoal) {
    seq.add(_SeqEvent.goal(messages.goal(atk.name, carrier.name), xg));
    return seq;
  }
  seq.add(_SeqEvent.shot(xg, 'Shot'));
  final pSave = 0.52 - 0.18 * baseQual + 0.24 * gkSave;
  if (rng.nextDouble() < pSave) {
    seq.add(_SeqEvent.text(messages.savedByKeeper()));
  } else {
    if (rng.nextDouble() < 0.18) {
      seq.add(_SeqEvent.text(messages.deflectedOut()));
    } else {
      seq.add(_SeqEvent.text(messages.offTarget()));
    }
  }
  return seq;
}
