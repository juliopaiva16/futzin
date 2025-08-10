import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:futzin/domain/entities.dart';

/// Reads a player pool (JSONL or JSON array) and samples random teams.
/// Outputs a JSONL where each line is a team config with computed overall metrics.
/// Also writes a CSV summarizing team attribute aggregates and metadata.
///
/// Usage:
///   dart run bin/simsets/build_random_teams_from_pool.dart --pool data/player_pool.jsonl --teams 200 --seed 99
///
/// Team overall calculation (baseline):
///   - Attack Overall: average of (selected attack attribute) weighted by position (FWD 1.1, MID 1.0, DEF 0.7, GK 0.4)
///   - Defense Overall: average of defense attribute weighted (GK 1.2, DEF 1.1, MID 0.8, FWD 0.4)
///   - Pace/Passing/Technique/Strength Averages (simple means)
///   - Ability counts appear as features in CSV.
///   - Global Overall: 0.55 * Attack + 0.45 * Defense (tunable) with ability adjustments (FIN/WALL/CAT/CAP small boosts).
///
/// Formation selection: random among defined formations. Auto picks lineup.
void main(List<String> args) async {
  String poolPath = 'data/player_pool.jsonl';
  int teamCount = 200;
  int seed = 123;
  String outTeams = 'data/random_teams.jsonl';
  String outCsv = 'data/random_teams_summary.csv';
  for (int i=0;i<args.length;i++) {
    final a = args[i];
    if (a == '--pool' && i+1<args.length) poolPath = args[++i];
    else if (a == '--teams' && i+1<args.length) teamCount = int.tryParse(args[++i]) ?? teamCount;
    else if (a == '--seed' && i+1<args.length) seed = int.tryParse(args[++i]) ?? seed;
    else if (a == '--outTeams' && i+1<args.length) outTeams = args[++i];
    else if (a == '--outCsv' && i+1<args.length) outCsv = args[++i];
  }
  final file = File(poolPath);
  if (!(await file.exists())) {
    stderr.writeln('Pool file not found: $poolPath');
    exit(2);
  }
  final content = await file.readAsString();
  List<dynamic> rawPlayers;
  if (content.trim().startsWith('[')) {
    rawPlayers = jsonDecode(content) as List;
  } else {
    rawPlayers = content.split('\n').where((l)=>l.trim().isNotEmpty).map((l){
      try { return jsonDecode(l); } catch(_){ return null; }
    }).whereType<Map<String,dynamic>>().toList();
  }
  final pool = rawPlayers.map((j)=> Player.fromJson(j as Map<String,dynamic>)).toList();
  if (pool.isEmpty) { stderr.writeln('Empty pool.'); exit(3); }
  final r = Random(seed);

  TeamConfig makeTeam(int idx) {
    // sample 16-22 players to form a squad.
    final squadSize = 16 + r.nextInt(7); // 16..22
    final chosen = <Player>[];
    // Ensure at least 2 GKs
    final gks = pool.where((p)=>p.pos==Position.GK).toList()..shuffle(r);
    chosen.addAll(gks.take(2).map((p)=>p.copy()));
    while (chosen.length < squadSize) {
      chosen.add(pool[r.nextInt(pool.length)].copy());
    }
    // assign a formation randomly
    final formation = Formation.formations[r.nextInt(Formation.formations.length)];
    final tactics = Tactics(
      attackBias: r.nextDouble()*2-1, // -1..1
      tempo: r.nextDouble(),
      pressing: r.nextDouble(),
      lineHeight: r.nextDouble(),
      width: r.nextDouble(),
      autoSubs: true,
    );
    final team = TeamConfig(name: 'Team$idx', formation: formation, tactics: tactics, squad: chosen);
    team.autoPick();
    return team;
  }

  double _overallAttack(List<Player> lineup) {
    double sum=0; double wSum=0; for (final p in lineup) { double w= switch(p.pos){
      Position.FWD=>1.1, Position.MID=>1.0, Position.DEF=>0.7, Position.GK=>0.4}; sum += p.attack*w; wSum+=w; }
    return wSum==0?0:sum/wSum;
  }
  double _overallDefense(List<Player> lineup) {
    double sum=0; double wSum=0; for (final p in lineup) { double w= switch(p.pos){
      Position.GK=>1.2, Position.DEF=>1.1, Position.MID=>0.8, Position.FWD=>0.4}; sum += p.defense*w; wSum+=w; }
    return wSum==0?0:sum/wSum;
  }
  Map<String,int> _abilityCounts(List<Player> lineup) {
    final counts = <String,int>{};
    for (final p in lineup) {
      for (final a in p.abilityCodes) { counts[a] = (counts[a]??0)+1; }
    }
    return counts;
  }
  double _globalOverall(double atk, double def, Map<String,int> abilities){
    double base = atk*0.55 + def*0.45;
    // modest ability adjustments (stack capped)
    double adj=0;
    adj += (abilities['FIN']??0)*0.25; // up to ~1-2 points
    adj += (abilities['WALL']??0)*0.20;
    adj += (abilities['CAT']??0)*0.30;
    adj += (abilities['CAP']??0)*0.15;
    return base + adj.clamp(0, 5);
  }

  final teamLines = <String>[]; // JSONL
  final csv = StringBuffer();
  // CSV header
  csv.writeln('team,formation,attackBias,tempo,pressing,lineHeight,width,atkOverall,defOverall,overall,paceAvg,passAvg,techAvg,strAvg,vis,pas,drb,fin,wall,cat,cap,eng,players');

  for (int i=0;i<teamCount;i++) {
    final t = makeTeam(i);
    final lineup = t.selected;
    final atk = _overallAttack(lineup);
    final def = _overallDefense(lineup);
    final abilities = _abilityCounts(lineup);
    final paceAvg = lineup.map((p)=>p.pace).fold<int>(0,(a,b)=>a+b)/lineup.length;
    final passAvg = lineup.map((p)=>p.passing).fold<int>(0,(a,b)=>a+b)/lineup.length;
    final techAvg = lineup.map((p)=>p.technique).fold<int>(0,(a,b)=>a+b)/lineup.length;
    final strAvg = lineup.map((p)=>p.strength).fold<int>(0,(a,b)=>a+b)/lineup.length;
    final overall = _globalOverall(atk, def, abilities);
    final jsonLine = {
      'name': t.name,
      'formation': t.formation.name,
      'tactics': t.tactics.toJson(),
      'squad': t.squad.map((p)=>p.toJson()).toList(),
      'selected': t.selectedIds.toList(),
      'atkOverall': atk,
      'defOverall': def,
      'overall': overall,
      'abilityCounts': abilities,
    };
    teamLines.add(jsonEncode(jsonLine));
    csv.writeln('${t.name},${t.formation.name},${t.tactics.attackBias.toStringAsFixed(3)},${t.tactics.tempo.toStringAsFixed(3)},${t.tactics.pressing.toStringAsFixed(3)},${t.tactics.lineHeight.toStringAsFixed(3)},${t.tactics.width.toStringAsFixed(3)},'
      '${atk.toStringAsFixed(2)},${def.toStringAsFixed(2)},${overall.toStringAsFixed(2)},${paceAvg.toStringAsFixed(1)},${passAvg.toStringAsFixed(1)},${techAvg.toStringAsFixed(1)},${strAvg.toStringAsFixed(1)},'
      '${abilities['VIS']??0},${abilities['PAS']??0},${abilities['DRB']??0},${abilities['FIN']??0},${abilities['WALL']??0},${abilities['CAT']??0},${abilities['CAP']??0},${abilities['ENG']??0},${t.squad.length}');
  }

  final outTeamsFile = File(outTeams)..parent.createSync(recursive: true);
  await outTeamsFile.writeAsString(teamLines.join('\n'));
  final outCsvFile = File(outCsv)..parent.createSync(recursive: true);
  await outCsvFile.writeAsString(csv.toString());
  stdout.writeln('Wrote $teamCount teams to $outTeams and summary CSV to $outCsv');
}
