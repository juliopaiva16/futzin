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
  final closeChance = EngineParams.legacyCloseBase + EngineParams.legacyCloseDefenseFactor * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj));
  if (rng.nextDouble() < closeChance) {
    seq.add(_SeqEvent.text(messages.defenseCloses(def.name)));
    return seq;
  }
  final passBase = 1 + ((atk.tactics.tempo + atk.tactics.width) * EngineParams.legacyPassTempoWidthFactor).round();
  final passCount = max(0, min(EngineParams.legacyPassMax, passBase + rng.nextInt(EngineParams.legacyPassExtraRand) - 1));
  for (int i = 0; i < passCount; i++) {
    final interceptChance = EngineParams.legacyInterceptBase +
        EngineParams.legacyInterceptDefenseFactor * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj));
    if (rng.nextDouble() < interceptChance) {
      final interceptor = pickDefender();
      seq.add(_SeqEvent.text(messages.intercepted(interceptor.name, def.name)));
      return seq;
    }
    final receiver = pickAttacker(exclude: carrier);
    seq.add(_SeqEvent.text(messages.pass(carrier.name, receiver.name)));
    carrier = receiver;
    final foulChance = EngineParams.legacyFoulBase + EngineParams.legacyFoulPressingFactor * def.tactics.pressing;
    if (rng.nextDouble() < foulChance) {
      final offender = pickDefender();
      seq.add(_SeqEvent.text(messages.lateFoul(def.name)));
      final redProb = EngineParams.legacyRedBase + EngineParams.legacyRedTempoFactor * atk.tactics.tempo;
      if (rng.nextDouble() < redProb) {
        seq.add(_SeqEvent.card(messages.foulRed(offender.name, def.name), offender,
            _CardType.red));
      } else {
        seq.add(_SeqEvent.card(messages.foulYellow(offender.name, def.name),
            offender, _CardType.yellow));
        if (offender.yellowCards == 1 && rng.nextDouble() < EngineParams.legacySecondYellowProb) {
          seq.add(_SeqEvent.card(messages.foulYellow(offender.name, def.name),
              offender, _CardType.yellow));
        }
      }
      if (rng.nextDouble() < EngineParams.legacyInjuryAfterFoulProb) {
        seq.add(_SeqEvent.text(messages.injuryAfterChallenge(carrier.name)));
        seq.add(_SeqEvent.injury(
            messages.injuryOutside(carrier.name, atk.name), carrier));
      }
      return seq;
    }
  }
  seq.add(_SeqEvent.text(messages.shoots(carrier.name)));
  final quality = atkRat.attackAdj / (atkRat.attackAdj + defRat.defenseAdj + 1e-6);
  double xg = EngineParams.legacyXgBase + EngineParams.legacyXgAttackFactor * quality + (rng.nextDouble() * EngineParams.legacyXgRandomRange - EngineParams.legacyXgRandomRange / 2);
  xg = xg.clamp(EngineParams.legacyXgMin, EngineParams.legacyXgMax);
  final gkSave = ((defRat.gk?.defense ?? 55) / 100.0);
  double pGoal = (xg * (0.95 - EngineParams.legacyGoalGkSaveFactor * gkSave)).clamp(EngineParams.legacyPGoalMin, EngineParams.legacyPGoalMax);
  if (rng.nextDouble() < pGoal) {
    seq.add(_SeqEvent.goal(messages.goal(atk.name, carrier.name), xg));
    return seq;
  }
  seq.add(_SeqEvent.shot(xg, 'Shot'));
  final pSave = EngineParams.legacyShotSaveBase - EngineParams.legacyShotSaveQualityFactor * quality + EngineParams.legacyShotSaveGkFactor * gkSave;
  if (rng.nextDouble() < pSave) {
    seq.add(_SeqEvent.text(messages.savedByKeeper()));
  } else {
    if (rng.nextDouble() < EngineParams.legacyDeflectOutProb) {
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
      if (d <= EngineParams.passLongMaxDist) list.add(p);
    }
    return list.isEmpty ? atkAlive.where((p) => p != from).toList() : list;
  }

  double _edgeWeight(Player from, Player to) {
    final d = dist(from, to).clamp(0.02, 1.0);
    // Base inverse distance weight (slightly favors shorter passes)
    double w = 1.0 / (0.08 + d);
    // Congestion penalty: look at defenders near mid-point of the prospective pass lane
    final mx = ((from.x ?? 0.5) + (to.x ?? 0.5)) * 0.5;
    final my = ((from.y ?? 0.5) + (to.y ?? 0.5)) * 0.5;
    final rad = EngineParams.graphEdgeCongestionRadius;
    if (rad > 0) {
      double density = 0.0;
      for (final defP in defAlive) {
        final dx = (defP.x ?? 0.5) - mx;
        final dy = (defP.y ?? 0.5) - my;
        final dr = sqrt(dx*dx + dy*dy);
        if (dr < rad) {
          // Weighted contribution (closer defenders contribute more)
            density += (1.0 - dr / rad);
        }
      }
      if (density > 0) {
        final penalty = (EngineParams.graphEdgeCongestionDefScale * density).clamp(0.0, 0.85);
        w *= (1.0 - penalty);
      }
    }
    return w <= 0 ? 1e-6 : w; // avoid zero weight
  }

  Player pickPass(Player from) {
    final recs = receiversFor(from);
    if (recs.isEmpty) return from;
    final weights = recs.map((p) => _edgeWeight(from, p)).toList();
    double sum = 0.0; for (final w in weights) sum += w;
    if (sum <= 0) {
      // Fallback to uniform if something went wrong
      return recs[rng.nextInt(recs.length)];
    }
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

  // Helper: multi-defender interception probability based on defenders near pass lane
  double multiDefInterceptProb(Player from, Player to) {
    // Represent pass as segment; approximate distance of defender to segment using projection
    double segDist(Player d) {
      final fx = from.x ?? 0.5, fy = from.y ?? 0.5;
      final tx = to.x ?? 0.5, ty = to.y ?? 0.5;
      final dx = tx - fx; final dy = ty - fy;
      if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return 999;
      final pdx = (d.x ?? 0.5) - fx; final pdy = (d.y ?? 0.5) - fy;
      final tRaw = ((pdx * dx) + (pdy * dy)) / (dx*dx + dy*dy);
      final t = tRaw.clamp(0.0, 1.0);
      // Lane window filter (ignore near endpoints)
      if (t < EngineParams.graphMultiInterceptLaneTMinV2 || t > EngineParams.graphMultiInterceptLaneTMaxV2) return 999;
      final cx = fx + dx * t; final cy = fy + dy * t;
      final ddx = (d.x ?? 0.5) - cx; final ddy = (d.y ?? 0.5) - cy;
      return sqrt(ddx*ddx + ddy*ddy);
    }
    final radius = EngineParams.graphMultiInterceptRadiusV2;
    final candidates = defAlive.where((d) => !d.sentOff && !d.injured).toList();
    double nonInterceptProd = 1.0; // multiplicative complement aggregation
    for (final d in candidates) {
      final distLane = segDist(d);
      if (distLane > radius) continue;
      final defFactor = (d.defense / 100.0) * EngineParams.graphMultiInterceptDefenseScaleV2;
      final proximity = 1.0 - distLane / radius; // 0 at edge -> 1 at lane
      double p = EngineParams.graphMultiInterceptPerDefBaseV2 * (1.0 + defFactor) * proximity;
      p = p.clamp(0.0, 0.25); // per defender cap
      nonInterceptProd *= (1.0 - p);
    }
    final agg = 1.0 - nonInterceptProd; // combined probability
    return agg.clamp(0.0, EngineParams.graphMultiInterceptMaxV2);
  }

  var carrier = pickStarter();
  seq.add(_SeqEvent.text(messages.findsSpace(carrier.name)));
  final closeChance = EngineParams.graphCloseBase + EngineParams.graphCloseDefenseFactor * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj));
  if (rng.nextDouble() < closeChance) {
    seq.add(_SeqEvent.text(messages.defenseCloses(def.name)));
    return seq;
  }
  final maxPassesBase = 1 + ((atk.tactics.tempo + atk.tactics.width) * EngineParams.graphPassTempoWidthFactor).round();
  final maxPasses = max(EngineParams.graphPassMin, min(EngineParams.graphPassMax, maxPassesBase));
  for (int i = 0; i < maxPasses; i++) {
    final rec = pickPass(carrier);
    final d = dist(carrier, rec).clamp(0.05, 1.0);
    final interceptBase = EngineParams.graphInterceptBase +
        EngineParams.graphInterceptDefenseFactor * (defRat.defenseAdj / (atkRat.attackAdj + defRat.defenseAdj)) +
        EngineParams.graphInterceptPressingFactor * def.tactics.pressing;
    final interceptChanceSingle = (interceptBase + EngineParams.graphInterceptDistFactor * (d - 0.15));
    final multiProb = multiDefInterceptProb(carrier, rec);
    final interceptChance = (interceptChanceSingle + multiProb).clamp(EngineParams.graphInterceptMin, EngineParams.graphInterceptMax);
    if (rng.nextDouble() < interceptChance) {
      final interceptor = pickDefender();
      seq.add(_SeqEvent.text(messages.intercepted(interceptor.name, def.name)));
      return seq;
    }
    seq.add(_SeqEvent.text(messages.pass(carrier.name, rec.name)));
    carrier = rec;
    final foulChance = EngineParams.graphFoulBase + EngineParams.graphFoulPressingFactor * def.tactics.pressing;
    if (rng.nextDouble() < foulChance) {
      final offender = pickDefender();
      seq.add(_SeqEvent.text(messages.lateFoul(def.name)));
      final redProb = EngineParams.graphRedBase + EngineParams.graphRedTempoFactor * atk.tactics.tempo;
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
  double xg = EngineParams.graphXgBase + EngineParams.graphXgCoeff * (EngineParams.graphXgBlendAttack * baseQual + (1 - EngineParams.graphXgBlendAttack) * posFactor) +
      (rng.nextDouble() * EngineParams.graphXgRandomRange - EngineParams.graphXgRandomRange / 2);
  xg = xg.clamp(EngineParams.graphXgMin, EngineParams.graphXgMax);
  final gkSave = ((defRat.gk?.defense ?? 55) / 100.0);
  double pGoal = (xg * (0.95 - EngineParams.graphGoalGkSaveFactor * gkSave)).clamp(EngineParams.graphPGoalMin, EngineParams.graphPGoalMax);
  if (rng.nextDouble() < pGoal) {
    seq.add(_SeqEvent.goal(messages.goal(atk.name, carrier.name), xg));
    return seq;
  }
  seq.add(_SeqEvent.shot(xg, 'Shot'));
  final pSave = EngineParams.graphShotSaveBase - EngineParams.graphShotSaveQualityFactor * baseQual + EngineParams.graphShotSaveGkFactor * gkSave;
  if (rng.nextDouble() < pSave) {
    seq.add(_SeqEvent.text(messages.savedByKeeper()));
  } else {
    if (rng.nextDouble() < EngineParams.graphDeflectOutProb) {
      seq.add(_SeqEvent.text(messages.deflectedOut()));
    } else {
      seq.add(_SeqEvent.text(messages.offTarget()));
    }
  }
  return seq;
}
