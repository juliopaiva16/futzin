import 'dart:async';
import 'dart:math';

import 'package:futzin/domain/entities.dart';
import 'package:futzin/domain/match_engine.dart';
import 'package:futzin/domain/messages.dart';

// Minimal stub messages for batch (not localized). Avoid UI deps.
class _StubMessages implements MatchMessages {
  @override String kickoff() => 'Kickoff';
  @override String calmMinute(int minute) => 'Calm minute';
  @override String recovery(String team, String player) => '$player recovers';
  @override String foulOn(String player) => 'Foul on $player';
  @override String anticipates(String team) => '$team anticipates';
  @override String pass(String from, String to) => '$from -> $to';
  @override String intercepted(String interceptor, String team) => 'Intercepted by $interceptor ($team)';
  @override String injuryAfterChallenge(String player) => '$player down';
  @override String findsSpace(String player) => '$player finds space';
  @override String defenseCloses(String team) => '$team closes down';
  @override String shoots(String player) => '$player shoots';
  @override String goal(String team, String player) => 'GOAL $team ($player)';
  @override String savedByKeeper() => 'Saved';
  @override String deflectedOut() => 'Deflected out';
  @override String offTarget() => 'Off target';
  @override String foulYellow(String player, String team) => 'Yellow $player';
  @override String foulRed(String player, String team) => 'Red $player';
  @override String foulRedBrutal(String player, String team) => 'Red (brutal) $player';
  @override String lateFoul(String team) => 'Late foul by $team';
  @override String injuryOutside(String player, String team) => '$player injured ($team)';
  @override String subTired(String team, String out, String inn) => 'Sub tired';
  @override String subInjury(String team, String out, String inn) => 'Sub injury';
  @override String subYellowRisk(String team, String out, String inn) => 'Sub card risk';
  @override String secondYellow(String player) => 'Second yellow $player';
  @override String endMatch() => 'Full time';
  @override String dribble(String player, String defender) => '$player vs $defender';
  @override String dribbleSuccess(String player) => '$player dribbles past!';
  @override String dribbleFail(String player) => '$player dispossessed';
  @override String longPass(String from, String to) => '$from long to $to';
  @override String backPass(String from, String to) => '$from back to $to';
  @override String holdUp(String player) => '$player holds it up';
  @override String launchForward(String from) => '$from launches forward';
}

// Generate a random player with basic attributes.
Player _rndPlayer(Random r, int idx, Position pos) {
  int base(int min, int max) => min + r.nextInt(max - min + 1);
  final attack = base(40, 80);
  final defense = base(40, 80);
  final stamina = base(60, 95);
  // Assign abilities with small probabilities (tunable)
  final abilities = <String>[];
  double roll() => r.nextDouble();
  // Core field abilities
  if (pos != Position.GK && roll() < 0.08) abilities.add('VIS');
  if (pos != Position.GK && roll() < 0.08) abilities.add('PAS');
  if (pos != Position.GK && roll() < 0.07) abilities.add('DRB');
  if (pos == Position.FWD && roll() < 0.10) abilities.add('FIN');
  if (pos == Position.DEF && roll() < 0.10) abilities.add('WALL');
  if (roll() < 0.06) abilities.add('ENG');
  if (roll() < 0.05) abilities.add('CAP');
  if (pos == Position.GK && roll() < 0.25) abilities.add('CAT');
  // Trim duplicates and cap at 3 (Player constructor enforces cap)
  final dedup = abilities.toSet().toList();
  return Player(
    id: 'P$idx${pos.name}',
    name: 'P$idx',
    pos: pos,
    attack: attack,
    defense: defense,
    stamina: stamina,
    pace: base(50, 90),
    passing: base(50, 90),
    technique: base(50, 90),
    strength: base(45, 85),
    abilityCodes: dedup,
  );
}

TeamConfig _rndTeam(Random r, String name) {
  final formation = Formation.formations.firstWhere((f) => f.name == '4-2-3-1', orElse: () => Formation.formations.first);
  final squad = <Player>[];
  squad.add(_rndPlayer(r, 0, Position.GK));
  for (int i = 1; i <= 4; i++) {
    squad.add(_rndPlayer(r, i, Position.DEF));
  }
  for (int i = 5; i <= 9; i++) {
    squad.add(_rndPlayer(r, i, Position.MID));
  }
  for (int i = 10; i <= 11; i++) {
    squad.add(_rndPlayer(r, i, Position.FWD));
  }
  final team = TeamConfig(
    name: name,
    formation: formation,
    tactics: Tactics(),
    squad: squad,
  );
  team.autoPick();
  return team;
}

Future<Map<String, dynamic>> simulateOne(int seed, bool useGraph) async {
  final r = Random(seed);
  final teamA = _rndTeam(r, 'A');
  final teamB = _rndTeam(r, 'B');
  final engine = MatchEngine(teamA, teamB, messages: _StubMessages(), seed: seed, useGraph: useGraph);
  engine.startManual();
  int shots = 0;
  int passesShort = 0; // successful short passes (->)
  int passesLong = 0;  // successful long passes
  int passesBack = 0;  // successful back passes
  int intercepts = 0;  // intercepted attempts (any type)
  int dribbleAttempts = 0;
  int dribbleSuccess = 0;
  int dribbleFail = 0;
  int holds = 0;
  int launchAttempts = 0;
  int launchSuccess = 0;
  int launchFail = 0;
  bool pendingLaunch = false; // flag to evaluate outcome on next event

  final nameMap = <String, Player>{
    for (final p in teamA.selected) p.name: p,
    for (final p in teamB.selected) p.name: p,
  };
  // Ability roster counts (once per match)
  int visPlayers = nameMap.values.where((p)=>p.hasAbility('VIS')).length;
  int pasPlayers = nameMap.values.where((p)=>p.hasAbility('PAS')).length;
  int drbPlayers = nameMap.values.where((p)=>p.hasAbility('DRB')).length;
  int finPlayers = nameMap.values.where((p)=>p.hasAbility('FIN')).length;
  int wallPlayers = nameMap.values.where((p)=>p.hasAbility('WALL')).length;
  int catPlayers = nameMap.values.where((p)=>p.hasAbility('CAT')).length;
  int capPlayers = nameMap.values.where((p)=>p.hasAbility('CAP')).length;

  // Ability event metrics
  int goalsFin = 0;
  int passesPasShort = 0;
  int passesPasLong = 0;
  int dribAttDrb = 0;
  int dribSuccDrb = 0;
  int interceptsWall = 0;
  int savesCat = 0;
  int goalsAgainstCat = 0;

  String _extractPassFrom(String txt) {
    // formats: "A -> B", "A long to B", "A back to B"
    if (txt.contains('->')) {
      return txt.split('->').first.trim();
    }
    if (txt.contains(' long to ')) {
      return txt.split(' long to ').first.trim();
    }
    if (txt.contains(' back to ')) {
      return txt.split(' back to ').first.trim();
    }
    return '';
  }

  final sub = engine.stream.listen((e) {
    final txtOrig = e.text;
    final txt = txtOrig.toLowerCase();
    if (e.kind == MatchEventKind.shot) shots++;

    // Goals (extract scorer for FIN)
    if (e.kind == MatchEventKind.goal) {
      final idx = txtOrig.indexOf('(');
      if (idx != -1) {
        final end = txtOrig.indexOf(')', idx + 1);
        if (end != -1) {
          final scorer = txtOrig.substring(idx + 1, end).trim();
            final player = nameMap[scorer];
            if (player != null && player.hasAbility('FIN')) goalsFin++;
            // goalsAgainstCat: defending side GK has CAT
            final defending = e.side == 1 ? teamB : teamA;
            final gk = defending.selected.firstWhere((p)=>p.pos==Position.GK, orElse: ()=>defending.selected.first);
            if (gk.hasAbility('CAT')) goalsAgainstCat++;
        }
      }
    }

    // Dribble tracking (attribute to DRB ability owner)
    if (txt.contains(' vs ')) {
      dribbleAttempts++;
      final playerName = txtOrig.split(' vs ').first.split("': ").last.trim();
      final player = nameMap[playerName];
      if (player != null && player.hasAbility('DRB')) dribAttDrb++;
    }
    if (txt.contains('dribbles past')) {
      dribbleSuccess++;
      final playerName = txtOrig.split(' dribbles past').first.split("': ").last.trim();
      final player = nameMap[playerName];
      if (player != null && player.hasAbility('DRB')) dribSuccDrb++;
    }
    if (txt.contains('dispossessed')) dribbleFail++;

    // Hold tracking
    if (txt.contains('holds it up')) holds++;

    // Launch tracking
    if (txt.contains('launches forward')) {
      launchAttempts++; pendingLaunch = true; return; // evaluate next event
    }
    if (pendingLaunch) {
      if (txt.contains('intercept')) {
        launchFail++;
      } else {
        launchSuccess++; // retained (any non-intercept event)
      }
      pendingLaunch = false;
    }

    // Pass classification + PAS ability
    if (txt.contains(' long to ')) {
      passesLong++; 
      final from = _extractPassFrom(txtOrig.split("': ").last);
      final player = nameMap[from];
      if (player != null && player.hasAbility('PAS')) passesPasLong++;
      return; // counted as pass
    }
    if (txt.contains(' back to ')) {
      passesBack++; 
      final from = _extractPassFrom(txtOrig.split("': ").last);
      final player = nameMap[from];
      if (player != null && player.hasAbility('PAS')) passesPasShort++;
      return; // counted as pass
    }
    if (txtOrig.contains('->')) {
      passesShort++; 
      final from = _extractPassFrom(txtOrig.split("': ").last);
      final player = nameMap[from];
      if (player != null && player.hasAbility('PAS')) passesPasShort++;
      return; // short pass
    }

    // Intercepts + WALL attribution
    if (txt.contains('intercept')) {
      intercepts++;
      // Interceptor name between "Intercepted by " and " (" or end
      final marker = 'Intercepted by ';
      final start = txtOrig.indexOf(marker);
      if (start != -1) {
        var tail = txtOrig.substring(start + marker.length).trim();
        final paren = tail.indexOf('(');
        if (paren != -1) tail = tail.substring(0, paren).trim();
        final interceptor = nameMap[tail];
        if (interceptor != null && interceptor.hasAbility('WALL')) interceptsWall++;
      }
    }

    // Saves + CAT
    if (txt == 'saved') {
      final defending = e.side == 1 ? teamB : teamA;
      final gk = defending.selected.firstWhere((p)=>p.pos==Position.GK, orElse: ()=>defending.selected.first);
      if (gk.hasAbility('CAT')) savesCat++;
    }
  });
  while (engine.isRunning) {
    engine.advanceMinute();
  }
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await sub.cancel();
  if (pendingLaunch) { // if match ended immediately after a launch treat as fail (lost context)
    launchFail++;
    pendingLaunch = false;
  }
  final passesAll = passesShort + passesLong + passesBack;
  final attemptsAll = passesAll + intercepts; // approximation (cannot separate type-specific failed attempts)
  final passesLegacyMetric = passesShort; // legacy behaviour for comparison
  final attemptsLegacyMetric = passesLegacyMetric + intercepts;
  return {
    'scoreA': engine.scoreA,
    'scoreB': engine.scoreB,
    'xgA': engine.xgA,
    'xgB': engine.xgB,
    'shots': shots,
    'passesShort': passesShort,
    'passesLong': passesLong,
    'passesBack': passesBack,
    'passesAll': passesAll,
    'intercepts': intercepts,
    'passAttemptsAll': attemptsAll,
    'passesLegacy': passesLegacyMetric,
    'passAttemptsLegacy': attemptsLegacyMetric,
    'dribbleAttempts': dribbleAttempts,
    'dribbleSuccess': dribbleSuccess,
    'dribbleFail': dribbleFail,
    'holds': holds,
    'launchAttempts': launchAttempts,
    'launchSuccess': launchSuccess,
    'launchFail': launchFail,
    'visPlayers': visPlayers,
    'pasPlayers': pasPlayers,
    'drbPlayers': drbPlayers,
    'finPlayers': finPlayers,
    'wallPlayers': wallPlayers,
    'catPlayers': catPlayers,
    'capPlayers': capPlayers,
    'goalsFin': goalsFin,
    'passesPasShort': passesPasShort,
    'passesPasLong': passesPasLong,
    'dribAttDrb': dribAttDrb,
    'dribSuccDrb': dribSuccDrb,
    'interceptsWall': interceptsWall,
    'savesCat': savesCat,
    'goalsAgainstCat': goalsAgainstCat,
  };
}

Future<void> main(List<String> args) async {
  final games = args.isNotEmpty ? int.parse(args[0]) : 50;
  final modeArg = args.length > 1 ? args[1] : 'legacy';
  final useGraph = modeArg.toLowerCase().startsWith('g');
  final results = <Map<String, dynamic>>[];
  int totalShort = 0, totalLong = 0, totalBack = 0, totalAllPass = 0;
  int totalIntercepts = 0;
  int totalLegacyPass = 0, totalLegacyAttempts = 0;
  int totalAttemptsAll = 0;
  int totalDribAtt = 0, totalDribSucc = 0, totalDribFail = 0;
  int totalHolds = 0;
  int totalLaunchAtt = 0, totalLaunchSucc = 0, totalLaunchFail = 0;
  int totalGoalsFin = 0;
  int totalPassesPasShort = 0, totalPassesPasLong = 0;
  int totalDrbAttDrb = 0, totalDrbSuccDrb = 0;
  int totalInterceptsWall = 0;
  int totalSavesCat = 0, totalGoalsAgainstCat = 0;
  int totalVisPlayers = 0, totalPasPlayers = 0, totalDrbPlayers = 0, totalFinPlayers = 0, totalWallPlayers = 0, totalCatPlayers = 0, totalCapPlayers = 0;
  for (int i = 0; i < games; i++) {
    final res = await simulateOne(1000 + i, useGraph);
    results.add(res);
    totalShort += res['passesShort'] as int;
    totalLong += res['passesLong'] as int;
    totalBack += res['passesBack'] as int;
    totalAllPass += res['passesAll'] as int;
    totalIntercepts += res['intercepts'] as int;
    totalAttemptsAll += res['passAttemptsAll'] as int;
    totalLegacyPass += res['passesLegacy'] as int;
    totalLegacyAttempts += res['passAttemptsLegacy'] as int;
    totalDribAtt += res['dribbleAttempts'] as int;
    totalDribSucc += res['dribbleSuccess'] as int;
    totalDribFail += res['dribbleFail'] as int;
    totalHolds += res['holds'] as int;
    totalLaunchAtt += res['launchAttempts'] as int;
    totalLaunchSucc += res['launchSuccess'] as int;
    totalLaunchFail += res['launchFail'] as int;
    totalGoalsFin += res['goalsFin'] as int;
    totalPassesPasShort += res['passesPasShort'] as int;
    totalPassesPasLong += res['passesPasLong'] as int;
    totalDrbAttDrb += res['dribAttDrb'] as int;
    totalDrbSuccDrb += res['dribSuccDrb'] as int;
    totalInterceptsWall += res['interceptsWall'] as int;
    totalSavesCat += res['savesCat'] as int;
    totalGoalsAgainstCat += res['goalsAgainstCat'] as int;
    totalVisPlayers += res['visPlayers'] as int;
    totalPasPlayers += res['pasPlayers'] as int;
    totalDrbPlayers += res['drbPlayers'] as int;
    totalFinPlayers += res['finPlayers'] as int;
    totalWallPlayers += res['wallPlayers'] as int;
    totalCatPlayers += res['catPlayers'] as int;
    totalCapPlayers += res['capPlayers'] as int;
  }
  double avg(String k) => results.map((m) => (m[k] as num).toDouble()).fold(0.0, (a, b) => a + b) / results.length;
  final avgXg = avg('xgA') + avg('xgB');
  final avgGoals = avg('scoreA') + avg('scoreB');
  final passSuccessAll = totalAttemptsAll == 0 ? 0.0 : totalAllPass / totalAttemptsAll;
  final passSuccessLegacy = totalLegacyAttempts == 0 ? 0.0 : totalLegacyPass / totalLegacyAttempts; // previous method
  final dribbleSuccRate = totalDribAtt == 0 ? 0.0 : totalDribSucc / totalDribAtt;
  final launchRetainRate = totalLaunchAtt == 0 ? 0.0 : totalLaunchSucc / totalLaunchAtt;
  final avgVisPlayers = totalVisPlayers / games;
  final avgPasPlayers = totalPasPlayers / games;
  final avgDrbPlayers = totalDrbPlayers / games;
  final avgFinPlayers = totalFinPlayers / games;
  final avgWallPlayers = totalWallPlayers / games;
  final avgCatPlayers = totalCatPlayers / games;
  final avgCapPlayers = totalCapPlayers / games;
  final drbAbilitySuccRate = totalDrbAttDrb == 0 ? 0.0 : totalDrbSuccDrb / totalDrbAttDrb;
  final pasShareShort = totalAllPass == 0 ? 0.0 : totalPassesPasShort / totalAllPass;
  final pasShareLong = totalLong == 0 ? 0.0 : totalPassesPasLong / totalLong;
  final wallInterceptShare = totalIntercepts == 0 ? 0.0 : totalInterceptsWall / totalIntercepts;
  final catSaveRate = (totalSavesCat + totalGoalsAgainstCat) == 0 ? 0.0 : totalSavesCat / (totalSavesCat + totalGoalsAgainstCat);
  print('Games: $games  Mode: ${useGraph ? 'GRAPH' : 'LEGACY'}');
  print('Avg Goals: ${avgGoals.toStringAsFixed(2)}  Avg xG: ${avgXg.toStringAsFixed(2)}');
  print('Avg Shots: ${avg('shots').toStringAsFixed(1)}');
  print('Passes (short/long/back): $totalShort/$totalLong/$totalBack  Intercepts: $totalIntercepts');
  print('Pass Success (ALL): ${(passSuccessAll * 100).toStringAsFixed(1)}%  (passes=$totalAllPass, attempts=$totalAttemptsAll)');
  print('Pass Success (LEGACY short only): ${(passSuccessLegacy * 100).toStringAsFixed(1)}%  (passes=$totalLegacyPass, attempts=$totalLegacyAttempts)');
  print('Dribbles: attempts=$totalDribAtt success=$totalDribSucc fail=$totalDribFail  SuccessRate=${(dribbleSuccRate*100).toStringAsFixed(1)}%');
  print('Holds: $totalHolds  Launches: $totalLaunchAtt retain=$totalLaunchSucc fail=$totalLaunchFail  RetainRate=${(launchRetainRate*100).toStringAsFixed(1)}%');
  print('Ability Rosters avg (VIS/PAS/DRB/FIN/WALL/CAT/CAP): ${avgVisPlayers.toStringAsFixed(1)}/${avgPasPlayers.toStringAsFixed(1)}/${avgDrbPlayers.toStringAsFixed(1)}/${avgFinPlayers.toStringAsFixed(1)}/${avgWallPlayers.toStringAsFixed(1)}/${avgCatPlayers.toStringAsFixed(1)}/${avgCapPlayers.toStringAsFixed(1)}');
  print('FIN goals: $totalGoalsFin  CAT saves: $totalSavesCat (saveRate=${(catSaveRate*100).toStringAsFixed(1)}%)');
  print('DRB ability: attempts=$totalDrbAttDrb success=$totalDrbSuccDrb rate=${(drbAbilitySuccRate*100).toStringAsFixed(1)}%');
  print('PAS passes: short=$totalPassesPasShort (${(pasShareShort*100).toStringAsFixed(1)}% of all), long=$totalPassesPasLong (${(pasShareLong*100).toStringAsFixed(1)}% of long)');
  print('WALL intercept share: ${(wallInterceptShare*100).toStringAsFixed(1)}%  (wallIntercepts=$totalInterceptsWall of $totalIntercepts)');
}
