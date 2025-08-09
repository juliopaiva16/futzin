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
}

// Generate a random player with basic attributes.
Player _rndPlayer(Random r, int idx, Position pos) {
  int base(int min, int max) => min + r.nextInt(max - min + 1);
  final attack = base(40, 80);
  final defense = base(40, 80);
  final stamina = base(60, 95);
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
    abilityCodes: const [],
  );
}

TeamConfig _rndTeam(Random r, String name) {
  final formation = Formation.formations.firstWhere((f) => f.name == '4-2-3-1', orElse: () => Formation.formations.first);
  final squad = <Player>[];
  squad.add(_rndPlayer(r, 0, Position.GK));
  for (int i = 1; i <= 4; i++) squad.add(_rndPlayer(r, i, Position.DEF));
  for (int i = 5; i <= 9; i++) squad.add(_rndPlayer(r, i, Position.MID));
  for (int i = 10; i <= 11; i++) squad.add(_rndPlayer(r, i, Position.FWD));
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
  int passes = 0; // successful passes (logged)
  int intercepts = 0; // intercepted attempts
  final sub = engine.stream.listen((e) {
    if (e.kind == MatchEventKind.shot) shots++;
    if (e.text.contains('->')) passes++;
    if (e.text.toLowerCase().contains('intercept')) intercepts++;
  });
  while (engine.isRunning) {
    engine.advanceMinute();
  }
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await sub.cancel();
  final attempts = passes + intercepts;
  return {
    'scoreA': engine.scoreA,
    'scoreB': engine.scoreB,
    'xgA': engine.xgA,
    'xgB': engine.xgB,
    'shots': shots,
    'passes': passes,
    'intercepts': intercepts,
    'passAttempts': attempts,
  };
}

Future<void> main(List<String> args) async {
  final games = args.isNotEmpty ? int.parse(args[0]) : 50;
  final modeArg = args.length > 1 ? args[1] : 'legacy';
  final useGraph = modeArg.toLowerCase().startsWith('g');
  final results = <Map<String, dynamic>>[];
  int totalPasses = 0;
  int totalAttempts = 0;
  for (int i = 0; i < games; i++) {
    final res = await simulateOne(1000 + i, useGraph);
    results.add(res);
    totalPasses += (res['passes'] as int);
    totalAttempts += (res['passAttempts'] as int);
  }
  double avg(String k) => results.map((m) => (m[k] as num).toDouble()).fold(0.0, (a, b) => a + b) / results.length;
  final avgXg = avg('xgA') + avg('xgB');
  final avgGoals = avg('scoreA') + avg('scoreB');
  final passSuccess = totalAttempts == 0 ? 0.0 : totalPasses / totalAttempts;
  print('Games: $games  Mode: ${useGraph ? 'GRAPH' : 'LEGACY'}');
  print('Avg Goals: ${avgGoals.toStringAsFixed(2)}  Avg xG: ${avgXg.toStringAsFixed(2)}');
  print('Avg Shots: ${avg('shots').toStringAsFixed(1)}  Pass events: ${avg('passes').toStringAsFixed(1)}  Intercepts: ${avg('intercepts').toStringAsFixed(1)}');
  print('Pass Success: ${(passSuccess * 100).toStringAsFixed(1)}% (passes=${totalPasses}, attempts=${totalAttempts})');
}
