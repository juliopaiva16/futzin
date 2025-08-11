import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:futzin/domain/entities.dart';
import 'package:futzin/domain/match_engine.dart';
import 'package:futzin/domain/messages.dart';
import 'package:futzin/domain/graph_logging.dart';

// Demo: run a single graph-engine match with instrumentation and print micro metrics.
// Usage: dart run bin/graph_log_demo.dart [seed]

void main(List<String> args) async {
  final seed = args.isNotEmpty ? int.tryParse(args.first) ?? 42 : 42;
  final rng = Random(seed);
  final teamA = _buildTeam('Alpha', rng);
  final teamB = _buildTeam('Beta', rng);
  teamA.autoPick();
  teamB.autoPick();

  final logDir = Directory('build/logs');
  if (!logDir.existsSync()) logDir.createSync(recursive: true);
  final filePath = 'build/logs/match_${DateTime.now().millisecondsSinceEpoch}.jsonl';
  final logger = JsonlGraphEventLogger(filePath);
  final engine = MatchEngine(teamA, teamB,
  messages: _StubMessages(), seed: seed, graphLogger: logger);
  engine.startManual();
  while (engine.isRunning) {
    engine.advanceMinute();
  }
  // Ensure all buffered log entries are written before reading
  logger.flush();
  logger.close();
  await Future.delayed(const Duration(milliseconds: 10));
  _deriveMetrics(filePath, seed);
}

void _deriveMetrics(String filePath, int seed) {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('Log file missing: $filePath');
    return;
  }
  final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
  print('DEBUG: lines read = \'${lines.length}\'');
  if (lines.isNotEmpty) {
    final first = _tryDecode(lines.first);
    print('DEBUG: first line keys=${first?.keys.toList()} t=${first?['t']}');
  }
  final possessions = <int, int>{};
  int passCompleted = 0;
  int passAttempt = 0;
  int dribbleSuccess = 0;
  int dribbleFail = 0;
  int shots = 0;
  int goals = 0;
  for (final line in lines) {
    final map = _tryDecode(line);
    if (map == null) continue;
    final pid = map['pid'] as int?;
    if (pid != null) possessions.update(pid, (v) => v + 1, ifAbsent: () => 1);
    final t = map['t'];
    if (t == 'shortPass' || t == 'longPass' || t == 'backPass' || t == 'launch_win') {
      passAttempt++; passCompleted++;
    } else if (t == 'launch_intercept' || t == 'intercept') {
      passAttempt++;
    } else if (t == 'dribble_success') {
      dribbleSuccess++;
    } else if (t == 'dribble_fail_intercept') {
      dribbleFail++;
    } else if (t == 'shot') {
      shots++;
    } else if (t == 'goal') {
      shots++; goals++;
    }
  }
  double passSuccessRate = passAttempt == 0 ? 0 : passCompleted / passAttempt;
  final seqLens = possessions.values.toList();
  seqLens.sort();
  double avgSeq = seqLens.isEmpty ? 0 : seqLens.reduce((a, b) => a + b) / seqLens.length;
  double p50 = seqLens.isEmpty ? 0 : seqLens[seqLens.length ~/ 2].toDouble();
  print('--- Graph Match Micro Metrics (seed=$seed) ---');
  print('Log file: $filePath');
  print('Pass success: ${(passSuccessRate * 100).toStringAsFixed(1)}% ($passCompleted/$passAttempt)');
  final drbTotal = dribbleSuccess + dribbleFail;
  print('Dribbles success: $dribbleSuccess fail: $dribbleFail (rate: ${drbTotal == 0 ? '0.0' : (100 * dribbleSuccess / drbTotal).toStringAsFixed(1)}%)');
  print('Shots: $shots Goals: $goals');
  print('Possessions: ${possessions.length} AvgSeqLen: ${avgSeq.toStringAsFixed(2)} P50: ${p50.toStringAsFixed(1)}');
}

Map<String, dynamic>? _tryDecode(String line) {
  try {
    return jsonDecode(line) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

TeamConfig _buildTeam(String name, Random rng) {
  final players = <Player>[];
  int idCounter = 0;
  Player mk(Position pos) {
    int baseA = 40 + rng.nextInt(40);
    int baseD = 40 + rng.nextInt(40);
    return Player(
      id: '${name[0]}${idCounter++}',
      name: '${name}_$idCounter',
      pos: pos,
      attack: baseA,
      defense: baseD,
      stamina: 60 + rng.nextInt(30),
      pace: 50 + rng.nextInt(40),
      passing: 50 + rng.nextInt(40),
      technique: 50 + rng.nextInt(40),
      strength: 50 + rng.nextInt(40),
    );
  }
  players.add(mk(Position.GK));
  for (int i = 0; i < 4; i++) players.add(mk(Position.DEF));
  for (int i = 0; i < 3; i++) players.add(mk(Position.MID));
  for (int i = 0; i < 3; i++) players.add(mk(Position.FWD));
  final team = TeamConfig(
    name: name,
    formation: Formation.formations.first,
    tactics: Tactics(),
    squad: players,
  );
  return team;
}

class _StubMessages implements MatchMessages {
  @override
  String backPass(String from, String to) => '$from recua para $to';
  @override
  String calmMinute(int m) => 'Minuto calmo';
  @override
  String recovery(String team, String player) => '$player recupera ($team)';
  @override
  String foulOn(String player) => 'Falta em $player';
  @override
  String anticipates(String team) => '$team antecipa';
  @override
  String defenseCloses(String defName) => 'Defesa $defName fecha';
  @override
  String deflectedOut() => 'Desvio pra escanteio';
  @override
  String dribble(String a, String b) => '$a encara $b';
  @override
  String dribbleFail(String a) => '$a perde a bola';
  @override
  String dribbleSuccess(String a) => '$a passa pelo marcador';
  @override
  String endMatch() => 'Fim de jogo';
  @override
  String findsSpace(String name) => '$name encontra espaço';
  @override
  String foulRed(String offender, String team) => 'Vermelho para $offender';
  @override
  String foulRedBrutal(String offender, String team) => 'Vermelho direto $offender';
  @override
  String foulYellow(String offender, String team) => 'Amarelo para $offender';
  @override
  String goal(String team, String scorer) => 'Gol de $scorer ($team)';
  @override
  String holdUp(String name) => '$name segura';
  @override
  String injuryAfterChallenge(String name) => '$name sente o lance';
  @override
  String injuryOutside(String name, String team) => '$name lesionado ($team)';
  @override
  String intercepted(String interceptor, String team) => '$interceptor intercepta';
  @override
  String kickoff() => 'Início';
  @override
  String lateFoul(String team) => 'Falta dura';
  @override
  String launchForward(String name) => '$name lança';
  @override
  String offTarget() => 'Pra fora';
  @override
  String pass(String from, String to) => '$from toca em $to';
  @override
  String savedByKeeper() => 'Defesa do goleiro';
  @override
  String secondYellow(String name) => 'Segundo amarelo $name';
  @override
  String shoots(String name) => '$name chuta';
  @override
  String longPass(String from, String to) => '$from lançamento para $to';
  @override
  String subInjury(String team, String out, String inn) => '$team troca por lesão: $out -> $inn';
  @override
  String subTired(String team, String out, String inn) => '$team troca por cansaço: $out -> $inn';
  @override
  String subYellowRisk(String team, String out, String inn) => '$team troca cartão: $out -> $inn';
}
