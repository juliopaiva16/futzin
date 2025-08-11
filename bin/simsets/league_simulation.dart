import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:futzin/domain/entities.dart';
import 'package:futzin/domain/match_engine.dart';
import 'package:futzin/domain/messages.dart';

// Reuse stub messages
class _StubMessages implements MatchMessages {
  // Match baseline stubs used in batch_baseline to keep parsing consistent
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

/// Simulates a round-robin mini league from a fixed set of team JSONL lines.
/// Each line must contain a pre-built team JSON (as produced by build_random_teams_from_pool.dart).
/// Outputs a CSV with matchup metadata and results so we can filter strong vs weak, etc.
///
/// Usage:
///   dart run bin/simsets/league_simulation.dart --teams data/random_teams.jsonl --out data/league_results.csv --games 3 --graph
///   (games indicates how many times each pair plays; 1 = single round-robin)
void main(List<String> args) async {
  String teamsPath = 'data/random_teams.jsonl';
  String outCsv = 'data/league_results.csv';
  int gamesPerPair = 1;
  // Graph engine only (MT9)
  int seed = 77;
  bool jitterTactics = true; // allow disabling for fixed baseline comparisons
  String? poolPath; // optional: build teams automatically from a player pool
  int? autoTeamsCount; // if set, will auto-generate teams before simulation
  bool styleSummary = true; // produce style summary CSV
  String? timelineOut; // optional per-match xG timeline output JSONL
  for (int i=0;i<args.length;i++) {
    final a = args[i];
    if (a == '--teams' && i+1<args.length) teamsPath = args[++i];
    else if (a == '--out' && i+1<args.length) outCsv = args[++i];
    else if (a == '--games' && i+1<args.length) gamesPerPair = int.tryParse(args[++i]) ?? gamesPerPair;
  // Mode flags ignored; graph is default
    else if (a == '--seed' && i+1<args.length) seed = int.tryParse(args[++i]) ?? seed;
    else if (a == '--noJitter') jitterTactics = false;
    else if (a == '--pool' && i+1<args.length) poolPath = args[++i];
    else if (a == '--autoTeams' && i+1<args.length) autoTeamsCount = int.tryParse(args[++i]);
  else if (a == '--noStyleSummary') styleSummary = false;
  else if (a == '--timelineOut' && i+1<args.length) timelineOut = args[++i];
  }
  // Auto-generate teams if requested
  if (autoTeamsCount != null) {
    if (poolPath == null) { stderr.writeln('--autoTeams requires --pool <player_pool.json|jsonl>'); exit(2); }
  final poolFile = File(poolPath);
    if (!poolFile.existsSync()) { stderr.writeln('Pool file not found: $poolPath'); exit(3); }
    final poolContent = await poolFile.readAsString();
    List<dynamic> rawPlayers;
    if (poolContent.trim().startsWith('[')) {
      rawPlayers = jsonDecode(poolContent) as List;
    } else {
      rawPlayers = poolContent.split('\n').where((l)=>l.trim().isNotEmpty).map((l){
        try { return jsonDecode(l); } catch(_){ return null; }
      }).whereType<Map<String,dynamic>>().toList();
    }
    final poolPlayers = rawPlayers.map((e)=>Player.fromJson(e as Map<String,dynamic>)).toList();
    if (poolPlayers.isEmpty) { stderr.writeln('Empty pool.'); exit(4); }
    final rGen = Random(seed);
    TeamConfig _buildTeam(int idx) {
      final squadSize = 16 + rGen.nextInt(7);
      final chosen = <Player>[];
      final gks = poolPlayers.where((p)=>p.pos==Position.GK).toList()..shuffle(rGen);
      chosen.addAll(gks.take(2).map((p)=>p.copy()));
      while (chosen.length < squadSize) { chosen.add(poolPlayers[rGen.nextInt(poolPlayers.length)].copy()); }
      final formation = Formation.formations[rGen.nextInt(Formation.formations.length)];
      final tactics = Tactics(
        attackBias: rGen.nextDouble()*2-1,
        tempo: rGen.nextDouble(),
        pressing: rGen.nextDouble(),
        lineHeight: rGen.nextDouble(),
        width: rGen.nextDouble(),
        autoSubs: true,
      );
      final t = TeamConfig(name: 'Team$idx', formation: formation, tactics: tactics, squad: chosen);
      t.autoPick();
      return t;
    }
    double _overallAttack(List<Player> lineup) { double sum=0, wSum=0; for (final p in lineup){ final w = switch(p.pos){ Position.FWD=>1.1, Position.MID=>1.0, Position.DEF=>0.7, Position.GK=>0.4 }; sum+=p.attack*w; wSum+=w;} return wSum==0?0:sum/wSum; }
    double _overallDefense(List<Player> lineup) { double sum=0, wSum=0; for (final p in lineup){ final w = switch(p.pos){ Position.GK=>1.2, Position.DEF=>1.1, Position.MID=>0.8, Position.FWD=>0.4 }; sum+=p.defense*w; wSum+=w;} return wSum==0?0:sum/wSum; }
    Map<String,int> _abilityCounts(List<Player> lineup){ final c=<String,int>{}; for(final p in lineup){ for(final a in p.abilityCodes){ c[a]=(c[a]??0)+1; } } return c; }
    double _globalOverall(double atk,double def, Map<String,int> ab){ double base = atk*0.55+def*0.45; double adj=0; adj+=(ab['FIN']??0)*0.25; adj+=(ab['WALL']??0)*0.20; adj+=(ab['CAT']??0)*0.30; adj+=(ab['CAP']??0)*0.15; return base + adj.clamp(0,5); }
    final outTeamsFile = File(teamsPath)..parent.createSync(recursive: true);
    final linesOut = <String>[];
  for (int i=0;i<autoTeamsCount;i++) {
      final team = _buildTeam(i);
      final lineup = team.selected;
      final atk = _overallAttack(lineup);
      final def = _overallDefense(lineup);
      final abilities = _abilityCounts(lineup);
      final overall = _globalOverall(atk, def, abilities);
      linesOut.add(jsonEncode({
        'name': team.name,
        'formation': team.formation.name,
        'tactics': team.tactics.toJson(),
        'squad': team.squad.map((p)=>p.toJson()).toList(),
        'selected': team.selectedIds.toList(),
        'atkOverall': atk,
        'defOverall': def,
        'overall': overall,
      }));
    }
    await outTeamsFile.writeAsString(linesOut.join('\n'));
    stdout.writeln('Auto-generated ${autoTeamsCount} teams into $teamsPath');
  }

  final lines = await File(teamsPath).readAsLines();
  final teams = <Map<String,dynamic>>[];
  for (final l in lines) { if (l.trim().isEmpty) continue; try { teams.add(jsonDecode(l)); } catch(_) {} }
  if (teams.isEmpty) { stderr.writeln('No teams parsed from $teamsPath'); exit(5); }
  final rnd = Random(seed);

  TeamConfig parseTeam(Map<String,dynamic> j) {
    final squad = (j['squad'] as List).map((e)=>Player.fromJson(e)).toList();
    final formName = j['formation'] as String;
    final formation = Formation.formations.firstWhere((f)=>f.name==formName, orElse: ()=>Formation.formations.first);
    final tactics = Tactics.fromJson(j['tactics']);
    final t = TeamConfig(name: j['name'], formation: formation, tactics: tactics, squad: squad);
    t.selectedIds.addAll((j['selected'] as List).map((e)=>e.toString()));
    return t;
  }

  // Prepare CSV
  final buf = StringBuffer();
  buf.writeln('teamA,teamB,atkA,defA,ovrA,atkB,defB,ovrB,atkDiff,defDiff,ovrDiff,formationA,formationB,attackBiasA,attackBiasB,tempoA,tempoB,pressingA,pressingB,lineHeightA,lineHeightB,widthA,widthB,styleA,styleB,scoreA,scoreB,xgA,xgB,shotsA,shotsB,passesShortA,passesShortB,passesLongA,passesLongB,passesBackA,passesBackB,interceptsA,interceptsB,dribAttA,dribAttB,dribSuccA,dribSuccB,engine');

  String classifyStyle(Tactics t) {
    if (t.attackBias > 0.3) return 'OFF';
    if (t.attackBias < -0.3) return 'DEF';
    return 'BAL';
  }

  // Round-robin pairs
  final timelines = <Map<String,dynamic>>[]; // per match timeline records
  int matchIndex = 0;
  for (int i=0;i<teams.length;i++) {
    for (int j=i+1;j<teams.length;j++) {
      final tAProto = teams[i];
      final tBProto = teams[j];
      for (int g=0; g<gamesPerPair; g++) {
        final teamA = parseTeam(tAProto);
        final teamB = parseTeam(tBProto);
        // Small random perturbation to tactics per match (simulate day variation)
        if (jitterTactics) {
          void jitter(Tactics t){
            double jVal(double v)=> (v + (rnd.nextDouble()-0.5)*0.1).clamp(0.0,1.0);
            t.attackBias = (t.attackBias + (rnd.nextDouble()-0.5)*0.2).clamp(-1.0,1.0);
            t.tempo = jVal(t.tempo); t.pressing = jVal(t.pressing); t.lineHeight = jVal(t.lineHeight); t.width = jVal(t.width);
          }
          jitter(teamA.tactics); jitter(teamB.tactics);
        }
        final atkA = (tAProto['atkOverall'] as num).toDouble();
        final defA = (tAProto['defOverall'] as num).toDouble();
        final ovrA = (tAProto['overall'] as num).toDouble();
        final atkB = (tBProto['atkOverall'] as num).toDouble();
        final defB = (tBProto['defOverall'] as num).toDouble();
        final ovrB = (tBProto['overall'] as num).toDouble();
  final engine = MatchEngine(teamA, teamB, messages: _StubMessages(), seed: 100000 + i*1000 + j*10 + g);
        // Event counters
        int shotsA=0, shotsB=0;
        int passesShortA=0, passesShortB=0;
        int passesLongA=0, passesLongB=0;
        int passesBackA=0, passesBackB=0;
        int interceptsA=0, interceptsB=0; // credited to defending side
        int dribAttA=0, dribAttB=0;
        int dribSuccA=0, dribSuccB=0;
        final sub = engine.stream.listen((e){
          final lower = e.text.toLowerCase();
          if (e.kind == MatchEventKind.shot || e.kind == MatchEventKind.goal) { if (e.side==1) shotsA++; else if (e.side==-1) shotsB++; }
          if (lower.contains(' vs ')) { if (e.side==1) dribAttA++; else if (e.side==-1) dribAttB++; }
          if (lower.contains('dribbles past')) { if (e.side==1) dribSuccA++; else if (e.side==-1) dribSuccB++; }
          // Passes (attacking side gets credit)
          bool isPass=false; bool isLong=false; bool isBack=false;
          if (lower.contains(' long to ')) { isPass=true; isLong=true; }
          else if (lower.contains(' back to ')) { isPass=true; isBack=true; }
          else if (e.text.contains('->')) { isPass=true; }
          if (isPass) {
            if (e.side==1) {
              if (isLong) passesLongA++; else if (isBack) passesBackA++; else passesShortA++;
            } else if (e.side==-1) {
              if (isLong) passesLongB++; else if (isBack) passesBackB++; else passesShortB++;
            }
          }
          if (lower.contains('intercept')) {
            // side represents attacking side; credit intercept to opposite
            if (e.side==1) interceptsB++; else if (e.side==-1) interceptsA++;
          }
        });
  engine.startManual();
  final timeline = <Map<String,dynamic>>[];
  timeline.add({'minute':0,'xgA':0.0,'xgB':0.0,'scoreA':0,'scoreB':0});
  while (engine.isRunning) { engine.advanceMinute(); timeline.add({'minute':engine.minute,'xgA':engine.xgA,'xgB':engine.xgB,'scoreA':engine.scoreA,'scoreB':engine.scoreB}); }
  timelines.add({'match':matchIndex,'teamA':teamA.name,'teamB':teamB.name,'styleA':classifyStyle(teamA.tactics),'styleB':classifyStyle(teamB.tactics),'timeline':timeline});
  matchIndex++;
        await sub.cancel();
        final styleA = classifyStyle(teamA.tactics);
        final styleB = classifyStyle(teamB.tactics);
        buf.writeln('${teamA.name},${teamB.name},${atkA.toStringAsFixed(2)},${defA.toStringAsFixed(2)},${ovrA.toStringAsFixed(2)},${atkB.toStringAsFixed(2)},${defB.toStringAsFixed(2)},${ovrB.toStringAsFixed(2)},'
          '${(atkA-atkB).toStringAsFixed(2)},${(defA-defB).toStringAsFixed(2)},${(ovrA-ovrB).toStringAsFixed(2)},${teamA.formation.name},${teamB.formation.name},'
          '${teamA.tactics.attackBias.toStringAsFixed(3)},${teamB.tactics.attackBias.toStringAsFixed(3)},${teamA.tactics.tempo.toStringAsFixed(3)},${teamB.tactics.tempo.toStringAsFixed(3)},${teamA.tactics.pressing.toStringAsFixed(3)},${teamB.tactics.pressing.toStringAsFixed(3)},'
          '${teamA.tactics.lineHeight.toStringAsFixed(3)},${teamB.tactics.lineHeight.toStringAsFixed(3)},${teamA.tactics.width.toStringAsFixed(3)},${teamB.tactics.width.toStringAsFixed(3)},'
          '${styleA},${styleB},${engine.scoreA},${engine.scoreB},${engine.xgA.toStringAsFixed(3)},${engine.xgB.toStringAsFixed(3)},'
          '${shotsA},${shotsB},${passesShortA},${passesShortB},${passesLongA},${passesLongB},${passesBackA},${passesBackB},${interceptsA},${interceptsB},${dribAttA},${dribAttB},${dribSuccA},${dribSuccB},GRAPH');
      }
    }
  }
  final outFile = File(outCsv)..parent.createSync(recursive: true);
  await outFile.writeAsString(buf.toString());
  stdout.writeln('League simulation CSV saved to $outCsv');

  if (styleSummary) {
    final resultLines = buf.toString().split('\n');
    if (resultLines.length > 1) {
      final summaryMap = <String, Map<String,dynamic>>{}; // key styleA|styleB
      for (int i=1;i<resultLines.length;i++) {
        final l = resultLines[i];
        if (l.trim().isEmpty) continue; final parts = l.split(',');
        if (parts.length < 44) continue; // ensure columns exist (header has 44)
        // Column indices per header comment
        final styleA = parts[23];
        final styleB = parts[24];
        final scoreA = int.tryParse(parts[25]) ?? 0;
        final scoreB = int.tryParse(parts[26]) ?? 0;
        final xgA = double.tryParse(parts[27]) ?? 0;
        final xgB = double.tryParse(parts[28]) ?? 0;
        final shotsA = int.tryParse(parts[29]) ?? 0;
        final shotsB = int.tryParse(parts[30]) ?? 0;
        final key = '$styleA|$styleB';
        final m = summaryMap.putIfAbsent(key, ()=>{'count':0,'goalsA':0,'goalsB':0,'xgA':0.0,'xgB':0.0,'shotsA':0,'shotsB':0,'winsA':0,'draws':0});
        m['count'] = (m['count'] as int)+1;
        m['goalsA'] = (m['goalsA'] as int)+scoreA;
        m['goalsB'] = (m['goalsB'] as int)+scoreB;
        m['xgA'] = (m['xgA'] as double)+xgA;
        m['xgB'] = (m['xgB'] as double)+xgB;
        m['shotsA'] = (m['shotsA'] as int)+shotsA;
        m['shotsB'] = (m['shotsB'] as int)+shotsB;
        if (scoreA>scoreB) m['winsA'] = (m['winsA'] as int)+1; else if (scoreA==scoreB) m['draws'] = (m['draws'] as int)+1;
      }
      final sumBuf = StringBuffer();
      sumBuf.writeln('styleA,styleB,matches,goalsA_avg,goalsB_avg,xgA_avg,xgB_avg,shotsA_avg,shotsB_avg,winRateA,drawRate');
      final symmetricMap = <String, Map<String,dynamic>>{}; // key style1|style2 (sorted)
      summaryMap.forEach((k,v){
        final partsKey = k.split('|');
        final c = v['count'] as int; if (c==0) return;
        double avg(num x)=> c==0?0:(x.toDouble()/c);
        final winRateA = c==0?0: (v['winsA'] as int)/c;
        final drawRate = c==0?0: (v['draws'] as int)/c;
        sumBuf.writeln('${partsKey[0]},${partsKey[1]},$c,'
          '${avg(v['goalsA']).toStringAsFixed(3)},${avg(v['goalsB']).toStringAsFixed(3)},'
          '${avg(v['xgA']).toStringAsFixed(3)},${avg(v['xgB']).toStringAsFixed(3)},'
          '${avg(v['shotsA']).toStringAsFixed(3)},${avg(v['shotsB']).toStringAsFixed(3)},'
          '${winRateA.toStringAsFixed(3)},${drawRate.toStringAsFixed(3)}');
        // Symmetric accumulation (style order independent)
        final keySymm = ([partsKey[0], partsKey[1]]..sort()).join('|');
        final sm = symmetricMap.putIfAbsent(keySymm, ()=>{'count':0,'goals':0.0,'xg':0.0,'shots':0.0});
        sm['count'] = (sm['count'] as int)+c;
        sm['goals'] = (sm['goals'] as double) + avg(v['goalsA']) + avg(v['goalsB']);
        sm['xg'] = (sm['xg'] as double) + avg(v['xgA']) + avg(v['xgB']);
        sm['shots'] = (sm['shots'] as double) + avg(v['shotsA']) + avg(v['shotsB']);
      });
      final outSummary = outCsv.replaceFirst('.csv', '_style_summary.csv');
      await File(outSummary).writeAsString(sumBuf.toString());
      stdout.writeln('Style summary CSV saved to $outSummary');
      // Write symmetric summary
      final symmBuf = StringBuffer();
      symmBuf.writeln('stylePair,matches,totalGoalsAvg,totalXgAvg,totalShotsAvg');
      symmetricMap.forEach((k,v){
        final c = v['count'] as int; if (c==0) return; symmBuf.writeln('$k,$c,'
          '${(v['goals'] as double).toStringAsFixed(3)},${(v['xg'] as double).toStringAsFixed(3)},${(v['shots'] as double).toStringAsFixed(3)}');
      });
      final outSymm = outCsv.replaceFirst('.csv', '_style_summary_symmetric.csv');
      await File(outSymm).writeAsString(symmBuf.toString());
      stdout.writeln('Symmetric style summary CSV saved to $outSymm');
      // Produce a matrix-style CSV for quick pivot (styleA rows vs styleB cols goalsForA avg)
      final styles = <String>{}; summaryMap.keys.forEach((k){ final sp=k.split('|'); styles.add(sp[0]); styles.add(sp[1]); });
      final styleList = styles.toList()..sort();
      final matrixBuf = StringBuffer();
      matrixBuf.write('style'); for (final sb in styleList) { matrixBuf.write(',$sb'); } matrixBuf.writeln();
      for (final sa in styleList) {
        matrixBuf.write(sa);
        for (final sb in styleList) {
          final keyDir = '$sa|$sb';
          final rec = summaryMap[keyDir];
          if (rec == null || (rec['count'] as int)==0) { matrixBuf.write(','); continue; }
          final gfA = (rec['goalsA'] as int)/(rec['count'] as int);
          matrixBuf.write(',${gfA.toStringAsFixed(3)}');
        }
        matrixBuf.writeln();
      }
      final outMatrix = outCsv.replaceFirst('.csv', '_style_matrix.csv');
      await File(outMatrix).writeAsString(matrixBuf.toString());
      stdout.writeln('Style matrix CSV saved to $outMatrix');
    }
  }
  if (timelineOut != null) {
    final tlFile = File(timelineOut)..parent.createSync(recursive: true);
    final sink = tlFile.openWrite();
    for (final m in timelines) { sink.writeln(jsonEncode(m)); }
    await sink.close();
    stdout.writeln('Timelines written to $timelineOut');
  }
}
