import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:futzin/domain/entities.dart';
import 'package:futzin/domain/match_engine.dart';
import 'package:futzin/domain/messages.dart';
import 'package:futzin/domain/graph_logging.dart';

// Batch runner producing aggregated metrics & distance histograms from instrumented matches.
// Usage: dart run bin/graph_log_batch_summary.dart <matches> [seed]

void main(List<String> args) async {
  final matches = args.isNotEmpty ? int.tryParse(args.first) ?? 50 : 50;
  final baseSeed = args.length > 1 ? int.tryParse(args[1]) ?? 1000 : 1000;
  final rand = Random(baseSeed);
  final outDir = Directory('build/logs');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final summaryCsv = StringBuffer();
  summaryCsv.writeln('matchId,seed,passSuccess,dribbleRate,shots,goals,avgPressure,avgSeqLen,avgPassDist,avgShotDist');

  // Distance bins - normalized pitch distances (0..1, x-only for simplicity)
  final passBinEdges = <double>[0, 0.08, 0.16, 0.24, 0.32, 0.40, 0.55];
  final shotBinEdges = <double>[0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.35];
  final passBinTotals = List<int>.filled(passBinEdges.length - 1, 0);
  final shotBinTotals = List<int>.filled(shotBinEdges.length - 1, 0);
  int globalPassCount = 0;
  int globalShotCount = 0;

  double aggPassSuccess = 0, aggDribbleRate = 0, aggShots = 0, aggGoals = 0, aggPressure = 0, aggSeq = 0, aggPassDist = 0, aggShotDist = 0;

  for (int i = 0; i < matches; i++) {
    final seed = baseSeed + i;
    final teamA = _buildTeam('A$i', Random(rand.nextInt(1 << 32)));
    final teamB = _buildTeam('B$i', Random(rand.nextInt(1 << 32)));
    teamA.autoPick(); teamB.autoPick();
    final logFile = 'build/logs/match_${i}_${DateTime.now().millisecondsSinceEpoch}.jsonl';
    final logger = JsonlGraphEventLogger(logFile);
  final eng = MatchEngine(teamA, teamB, messages: _StubMessages(), seed: seed, graphLogger: logger);
    eng.startManual();
    while (eng.isRunning) { eng.advanceMinute(); }
  logger.flush();
  logger.close();
  await Future.delayed(const Duration(milliseconds: 5));
    final m = _extractMetrics(logFile, passBinEdges, passBinTotals, shotBinEdges, shotBinTotals, (v){globalPassCount+=v;}, (v){globalShotCount+=v;});
    summaryCsv.writeln('${eng.matchId},$seed,${m.passSuccess.toStringAsFixed(4)},${m.dribbleRate.toStringAsFixed(4)},${m.shots},${m.goals},${m.avgPressure.toStringAsFixed(4)},${m.avgSeqLen.toStringAsFixed(3)},${m.avgPassDist.toStringAsFixed(4)},${m.avgShotDist.toStringAsFixed(4)}');
    aggPassSuccess += m.passSuccess; aggDribbleRate += m.dribbleRate; aggShots += m.shots; aggGoals += m.goals; aggPressure += m.avgPressure; aggSeq += m.avgSeqLen; aggPassDist += m.avgPassDist; aggShotDist += m.avgShotDist;
  }

  final summaryPath = 'build/logs/batch_summary.csv';
  File(summaryPath).writeAsStringSync(summaryCsv.toString());

  // Write histogram CSVs
  final passBinsCsv = StringBuffer('bin_from,bin_to,count,share\n');
  for (int i=0;i<passBinTotals.length;i++) {
    final c = passBinTotals[i];
    final share = globalPassCount==0?0:c/globalPassCount;
    passBinsCsv.writeln('${passBinEdges[i]},${passBinEdges[i+1]},$c,${share.toStringAsFixed(4)}');
  }
  File('build/logs/pass_distance_bins.csv').writeAsStringSync(passBinsCsv.toString());

  final shotBinsCsv = StringBuffer('bin_from,bin_to,count,share\n');
  for (int i=0;i<shotBinTotals.length;i++) {
    final c = shotBinTotals[i];
    final share = globalShotCount==0?0:c/globalShotCount;
    shotBinsCsv.writeln('${shotBinEdges[i]},${shotBinEdges[i+1]},$c,${share.toStringAsFixed(4)}');
  }
  File('build/logs/shot_distance_bins.csv').writeAsStringSync(shotBinsCsv.toString());

  if (matches > 0) {
    print('Averages over $matches matches: passSuccess=${(aggPassSuccess/matches).toStringAsFixed(3)} dribbleRate=${(aggDribbleRate/matches).toStringAsFixed(3)} shots=${(aggShots/matches).toStringAsFixed(2)} goals=${(aggGoals/matches).toStringAsFixed(2)} avgPressure=${(aggPressure/matches).toStringAsFixed(3)} avgSeqLen=${(aggSeq/matches).toStringAsFixed(2)} avgPassDist=${(aggPassDist/matches).toStringAsFixed(3)} avgShotDist=${(aggShotDist/matches).toStringAsFixed(3)}');
    print('Wrote:');
    print(' - $summaryPath');
    print(' - build/logs/pass_distance_bins.csv');
    print(' - build/logs/shot_distance_bins.csv');
  }
}

class _Metrics {
  final double passSuccess;
  final double dribbleRate;
  final int shots;
  final int goals;
  final double avgPressure;
  final double avgSeqLen;
  final double avgPassDist;
  final double avgShotDist;
  _Metrics(this.passSuccess,this.dribbleRate,this.shots,this.goals,this.avgPressure,this.avgSeqLen,this.avgPassDist,this.avgShotDist);
}

_Metrics _extractMetrics(
  String logPath,
  List<double> passEdges,
  List<int> passTotals,
  List<double> shotEdges,
  List<int> shotTotals,
  void Function(int addedPasses) passAcc,
  void Function(int addedShots) shotAcc,
) {
  final lines = File(logPath).readAsLinesSync();
  int passCompleted=0, passAttempt=0, drbSucc=0, drbFail=0, shots=0, goals=0; double pressureSum=0; int pressureN=0; final poss=<int,int>{};
  double passDistSum=0; int passDistN=0; double shotDistSum=0; int shotDistN=0; int addedPasses=0; int addedShots=0;
  for (final l in lines) {
    if (l.trim().isEmpty) continue; Map<String,dynamic>? m; try { m=jsonDecode(l); } catch(_){ continue; }
    final t = m?['t']; final pid=m?['pid']; if (pid is int) poss.update(pid,(v)=>v+1, ifAbsent: ()=>1);
    final prs=m?['prs']; if (prs is num){pressureSum+=prs.toDouble(); pressureN++;}
    if (t=='shortPass'||t=='longPass'||t=='backPass'||t=='launch_win'||t=='launch_intercept'||t=='intercept') {
      final distVal = (m?['dist'] as num?)?.toDouble();
      if (distVal!=null){ passDistSum+=distVal; passDistN++; _accumulateBins(distVal, passEdges, passTotals); addedPasses++; }
    }
    switch (t) {
      case 'shortPass': case 'longPass': case 'backPass': case 'launch_win': passAttempt++; passCompleted++; break;
      case 'launch_intercept': case 'intercept': passAttempt++; break;
      case 'dribble_success': drbSucc++; break; case 'dribble_fail_intercept': drbFail++; break;
      case 'shot': case 'goal': {
        final fx = (m?['fx'] as num?)?.toDouble();
        final side = m?['s'];
        if (fx!=null && side is String) {
          final shotDist = side=='A' ? (1.0 - fx).clamp(0.0,1.0) : fx.clamp(0.0,1.0);
          shotDistSum += shotDist; shotDistN++; _accumulateBins(shotDist, shotEdges, shotTotals); addedShots++;
        }
        shots++;
        if (t=='goal') goals++;
        break; }
    }
  }
  passAcc(addedPasses); shotAcc(addedShots);
  final passSuccess = passAttempt==0?0:passCompleted/passAttempt;
  final dribbleRate = (drbSucc+drbFail)==0?0:drbSucc/(drbSucc+drbFail);
  final avgPressure = pressureN==0?0:pressureSum/pressureN;
  final seqLens = poss.values.toList();
  final avgSeq = seqLens.isEmpty?0:seqLens.reduce((a,b)=>a+b)/seqLens.length;
  final avgPassDist = passDistN==0?0:passDistSum/passDistN;
  final avgShotDist = shotDistN==0?0:shotDistSum/shotDistN;
  return _Metrics(passSuccess.toDouble(), dribbleRate.toDouble(), shots, goals, avgPressure.toDouble(), avgSeq.toDouble(), avgPassDist.toDouble(), avgShotDist.toDouble());
}

void _accumulateBins(double v, List<double> edges, List<int> totals) {
  for (int i=0;i<edges.length-1;i++) {
    if (v >= edges[i] && v < edges[i+1]) { totals[i]++; return; }
  }
}

TeamConfig _buildTeam(String name, Random rng) {
  final players=<Player>[]; int id=0;
  Player mk(Position pos){
    int a=40+rng.nextInt(40); int d=40+rng.nextInt(40);
    return Player(id:'${name[0]}${id++}', name:'${name}_$id', pos:pos, attack:a, defense:d, stamina:60+rng.nextInt(30), pace:50+rng.nextInt(40), passing:50+rng.nextInt(40), technique:50+rng.nextInt(40), strength:50+rng.nextInt(40));
  }
  players.add(mk(Position.GK));
  for (int i=0;i<4;i++) players.add(mk(Position.DEF));
  for (int i=0;i<3;i++) players.add(mk(Position.MID));
  for (int i=0;i<3;i++) players.add(mk(Position.FWD));
  return TeamConfig(name: name, formation: Formation.formations.first, tactics: Tactics(), squad: players);
}

class _StubMessages implements MatchMessages {
  @override String kickoff() => 'Início';
  @override String calmMinute(int minute) => 'Calmo';
  @override String recovery(String team, String player) => '$player recupera ($team)';
  @override String foulOn(String player) => 'Falta em $player';
  @override String anticipates(String team) => '$team antecipa';
  @override String pass(String from, String to) => '$from toca em $to';
  @override String intercepted(String interceptor, String team) => '$interceptor intercepta';
  @override String injuryAfterChallenge(String player) => '$player sente';
  @override String findsSpace(String player) => '$player encontra espaço';
  @override String defenseCloses(String team) => 'Defesa $team fecha';
  @override String shoots(String player) => '$player chuta';
  @override String goal(String team, String player) => 'Gol de $player ($team)';
  @override String savedByKeeper() => 'Defendido';
  @override String deflectedOut() => 'Desviado';
  @override String offTarget() => 'Pra fora';
  @override String foulYellow(String player, String team) => 'Amarelo $player';
  @override String foulRed(String player, String team) => 'Vermelho $player';
  @override String foulRedBrutal(String player, String team) => 'Vermelho direto $player';
  @override String lateFoul(String team) => 'Falta dura';
  @override String injuryOutside(String player, String team) => '$player lesionado';
  @override String subTired(String team, String out, String inn) => '$team troca cansaço';
  @override String subInjury(String team, String out, String inn) => '$team troca lesão';
  @override String subYellowRisk(String team, String out, String inn) => '$team troca cartão';
  @override String secondYellow(String player) => 'Segundo amarelo $player';
  @override String endMatch() => 'Fim';
  @override String dribble(String player, String defender) => '$player encara $defender';
  @override String dribbleSuccess(String player) => '$player passa';
  @override String dribbleFail(String player) => '$player perde';
  @override String longPass(String from, String to) => '$from lança longo $to';
  @override String backPass(String from, String to) => '$from recua $to';
  @override String holdUp(String player) => '$player segura';
  @override String launchForward(String from) => '$from lança';
}
