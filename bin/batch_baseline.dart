import 'dart:async';
import 'dart:math';

import 'package:futzin/domain/entities.dart';
import 'package:futzin/domain/match_engine.dart';
import 'package:futzin/domain/messages.dart';
import 'package:futzin/domain/engine_params.dart';

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
  // Stamina tracking accumulators per quarter
  double q1Sum = 0, q2Sum = 0, q3Sum = 0, q4Sum = 0; int q1Count = 0, q2Count = 0, q3Count = 0, q4Count = 0;
  double engFinalSum = 0, nonEngFinalSum = 0; int engFinalCount = 0, nonEngFinalCount = 0;
  // NEW: per-position final stamina segmentation
  double engFinalGKSum = 0, engFinalDEFSum = 0, engFinalMIDSum = 0, engFinalFWDSum = 0;
  double nonEngFinalGKSum = 0, nonEngFinalDEFSum = 0, nonEngFinalMIDSum = 0, nonEngFinalFWDSum = 0;
  int engFinalGKCnt = 0, engFinalDEFCnt = 0, engFinalMIDCnt = 0, engFinalFWDCnt = 0;
  int nonEngFinalGKCnt = 0, nonEngFinalDEFCnt = 0, nonEngFinalMIDCnt = 0, nonEngFinalFWDCnt = 0;
  // NEW: decay tracking per minute (sum of stamina drops)
  double engDecaySum = 0, nonEngDecaySum = 0; int engDecayTicks = 0, nonEngDecayTicks = 0;
  // NEW: ENG distribution by position (lineup counts)
  int engPlayersGK = 0, engPlayersDEF = 0, engPlayersMID = 0, engPlayersFWD = 0;
  // Re-added event counters lost during instrumentation merge
  int shots = 0;
  int passesShort = 0; // successful short passes
  int passesLong = 0;  // successful long passes
  int passesBack = 0;  // successful back passes
  int intercepts = 0;  // intercepted attempts
  // New granular attempt counters (graph outcome logging only)
  int attemptsShort = 0; int attemptsLong = 0; int attemptsBack = 0;
  int interceptShort = 0; int interceptLong = 0; int interceptBack = 0;
  int dribbleAttempts = 0;
  int dribbleSuccess = 0;
  int dribbleFail = 0;
  int holds = 0;
  int launchAttempts = 0;
  int launchSuccess = 0;
  int launchFail = 0;
  bool pendingLaunch = false;

  final nameMap = <String, Player>{
    for (final p in teamA.selected) p.name: p,
    for (final p in teamB.selected) p.name: p,
  };
  // Count ENG per position once (initial lineup)
  for (final p in nameMap.values) {
    if (p.hasAbility('ENG')) {
      switch (p.pos) {
        case Position.GK: engPlayersGK++; break;
        case Position.DEF: engPlayersDEF++; break;
        case Position.MID: engPlayersMID++; break;
        case Position.FWD: engPlayersFWD++; break;
      }
    }
  }

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
  // When using graph + outcome logging, infer attempted pass type from actionType pattern embedded earlier is not present in text.
  // Fallback classification will be refined after log integration; keep legacy text parsing only.
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
  // If graph mode with outcome logging, attach a temporary logger to capture action outcomes for granular pass attempts.
  // Simpler approach: if engine.useGraph and EngineParams.graphLogPassOutcome, we intercept MatchEngine.graphLogger? Not exposed here.
  // For now, approximate by inferring attempts from success+intercepts (already done). Future: wire a memory logger.
  // NEW: previous stamina map for decay deltas
  final prevStam = <String,double>{
    for (final p in [...teamA.selected, ...teamB.selected]) p.id : p.currentStamina
  };
  int minuteSamples = 0;
  while (engine.isRunning) {
    engine.advanceMinute();
    final m = engine.minute;
  if (m >= 1 && m <= 90) {
      final all = [...teamA.selected, ...teamB.selected];
      for (final p in all) {
        final st = p.currentStamina;
        // compute decay delta (previous - current if positive)
        final prev = prevStam[p.id] ?? st;
        final drop = (prev - st); // should be >=0
        if (drop > 0) {
          if (p.hasAbility('ENG')) { engDecaySum += drop; engDecayTicks++; } else { nonEngDecaySum += drop; nonEngDecayTicks++; }
        }
        prevStam[p.id] = st;
  if (m <= 22) { q1Sum += st; q1Count++; }
  else if (m <= 45) { q2Sum += st; q2Count++; }
  else if (m <= 68) { q3Sum += st; q3Count++; }
  else { q4Sum += st; q4Count++; }
      }
      if (m == 90) {
        for (final p in all) {
          if (p.hasAbility('ENG')) {
            engFinalSum += p.currentStamina; engFinalCount++;
            switch (p.pos) {
              case Position.GK: engFinalGKSum += p.currentStamina; engFinalGKCnt++; break;
              case Position.DEF: engFinalDEFSum += p.currentStamina; engFinalDEFCnt++; break;
              case Position.MID: engFinalMIDSum += p.currentStamina; engFinalMIDCnt++; break;
              case Position.FWD: engFinalFWDSum += p.currentStamina; engFinalFWDCnt++; break;
            }
          } else {
            nonEngFinalSum += p.currentStamina; nonEngFinalCount++;
            switch (p.pos) {
              case Position.GK: nonEngFinalGKSum += p.currentStamina; nonEngFinalGKCnt++; break;
              case Position.DEF: nonEngFinalDEFSum += p.currentStamina; nonEngFinalDEFCnt++; break;
              case Position.MID: nonEngFinalMIDSum += p.currentStamina; nonEngFinalMIDCnt++; break;
              case Position.FWD: nonEngFinalFWDSum += p.currentStamina; nonEngFinalFWDCnt++; break;
            }
          }
        }
  }
  minuteSamples++;
    }
  }
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await sub.cancel();
  if (pendingLaunch) { // if match ended immediately after a launch treat as fail (lost context)
    launchFail++;
    pendingLaunch = false;
  }
  final passesAll = passesShort + passesLong + passesBack;
  // If granular counters captured (graph mode with outcome logging), compute attempts by summing successes + intercepts by type.
  bool granular = useGraph && EngineParams.graphLogPassOutcome; // need EngineParams import for constant; add at top
  final attemptsAll = granular ? (attemptsShort + attemptsLong + attemptsBack) : (passesAll + intercepts);
  if (!granular) {
    attemptsShort = passesShort + intercepts; // legacy approximation (cannot split)
    attemptsLong = passesLong; // unknown intercept share
    attemptsBack = passesBack; // unknown intercept share
  }
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
  'attemptsShort': attemptsShort,
  'attemptsLong': attemptsLong,
  'attemptsBack': attemptsBack,
  'interceptShort': interceptShort,
  'interceptLong': interceptLong,
  'interceptBack': interceptBack,
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
  'q1Avg': q1Count==0?0:q1Sum/q1Count,
  'q2Avg': q2Count==0?0:q2Sum/q2Count,
  'q3Avg': q3Count==0?0:q3Sum/q3Count,
  'q4Avg': q4Count==0?0:q4Sum/q4Count,
  'engFinalAvg': engFinalCount==0?0:engFinalSum/engFinalCount,
  'nonEngFinalAvg': nonEngFinalCount==0?0:nonEngFinalSum/nonEngFinalCount,
    // NEW: per-position final stamina averages
    'engFinalGKAvg': engFinalGKCnt==0?0:engFinalGKSum/engFinalGKCnt,
    'engFinalDEFAvg': engFinalDEFCnt==0?0:engFinalDEFSum/engFinalDEFCnt,
    'engFinalMIDAvg': engFinalMIDCnt==0?0:engFinalMIDSum/engFinalMIDCnt,
    'engFinalFWDAvg': engFinalFWDCnt==0?0:engFinalFWDSum/engFinalFWDCnt,
    'nonEngFinalGKAvg': nonEngFinalGKCnt==0?0:nonEngFinalGKSum/nonEngFinalGKCnt,
    'nonEngFinalDEFAvg': nonEngFinalDEFCnt==0?0:nonEngFinalDEFSum/nonEngFinalDEFCnt,
    'nonEngFinalMIDAvg': nonEngFinalMIDCnt==0?0:nonEngFinalMIDSum/nonEngFinalMIDCnt,
    'nonEngFinalFWDAvg': nonEngFinalFWDCnt==0?0:nonEngFinalFWDSum/nonEngFinalFWDCnt,
    // NEW: decay metrics
  'engDecayPerMin': (minuteSamples==0||engDecayTicks==0)?0:(engDecaySum/engDecayTicks),
  'nonEngDecayPerMin': (minuteSamples==0||nonEngDecayTicks==0)?0:(nonEngDecaySum/nonEngDecayTicks),
    // NEW: ENG distribution counts
    'engPlayersGK': engPlayersGK,
    'engPlayersDEF': engPlayersDEF,
    'engPlayersMID': engPlayersMID,
    'engPlayersFWD': engPlayersFWD,
  };
}

Future<void> main(List<String> args) async {
  // Accept either: <games> <mode>  OR  --games <n> --graph/--legacy
  int games = 50; bool useGraph = false;
  if (args.isNotEmpty) {
    for (int i=0;i<args.length;i++) {
      final a = args[i];
      if (a == '--games' && i+1 < args.length) { games = int.tryParse(args[i+1]) ?? games; i++; continue; }
      if (i==0 && int.tryParse(a) != null) { games = int.parse(a); continue; }
      if (a == '--graph' || a.toLowerCase().startsWith('graph')) { useGraph = true; continue; }
      if (a == '--legacy' || a.toLowerCase().startsWith('legacy')) { useGraph = false; continue; }
      if (i==1 && (a.startsWith('g')||a.startsWith('G'))) { useGraph = true; }
    }
  }
  final results = <Map<String, dynamic>>[];
  int totalShort = 0, totalLong = 0, totalBack = 0, totalAllPass = 0;
  int totalIntercepts = 0;
  int totalAttemptsShort = 0, totalAttemptsLong = 0, totalAttemptsBack = 0;
  int totalInterceptShort = 0, totalInterceptLong = 0, totalInterceptBack = 0;
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
  double sumQ1=0,sumQ2=0,sumQ3=0,sumQ4=0,sumEng=0,sumNon=0; int nQ=0; // nQ == games with data
  double sumEngFinalPlayers=0; int cntEngFinalPlayers=0; // total ENG player final stamina
  double sumNonEngFinalPlayers=0; int cntNonEngFinalPlayers=0;
  // NEW aggregation accumulators
  double sumEngDecay=0,sumNonEngDecay=0; int cntEngDecay=0,cntNonEngDecay=0;
  int sumEngGK=0,sumEngDEF=0,sumEngMID=0,sumEngFWD=0;
  double sumEngFinalGK=0,sumEngFinalDEF=0,sumEngFinalMID=0,sumEngFinalFWD=0;
  double sumNonEngFinalGK=0,sumNonEngFinalDEF=0,sumNonEngFinalMID=0,sumNonEngFinalFWD=0;
  int gamesWithEngGK=0,gamesWithEngDEF=0,gamesWithEngMID=0,gamesWithEngFWD=0; // track presence
  for (int i = 0; i < games; i++) {
    final res = await simulateOne(1000 + i, useGraph);
    results.add(res);
    totalShort += res['passesShort'] as int;
    totalLong += res['passesLong'] as int;
    totalBack += res['passesBack'] as int;
    totalAllPass += res['passesAll'] as int;
    totalIntercepts += res['intercepts'] as int;
    totalAttemptsAll += res['passAttemptsAll'] as int;
    if (res.containsKey('attemptsShort')) {
      totalAttemptsShort += res['attemptsShort'] as int;
      totalAttemptsLong += res['attemptsLong'] as int;
      totalAttemptsBack += res['attemptsBack'] as int;
      totalInterceptShort += res['interceptShort'] as int;
      totalInterceptLong += res['interceptLong'] as int;
      totalInterceptBack += res['interceptBack'] as int;
    }
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
  sumQ1 += (res['q1Avg'] as num).toDouble();
  sumQ2 += (res['q2Avg'] as num).toDouble();
  sumQ3 += (res['q3Avg'] as num).toDouble();
  sumQ4 += (res['q4Avg'] as num).toDouble();
  sumEng += (res['engFinalAvg'] as num).toDouble();
  sumNon += (res['nonEngFinalAvg'] as num).toDouble();
  nQ++;
  // Player-level finals (exclude zero when no ENG)
  final engAvgFinal = (res['engFinalAvg'] as num).toDouble();
  final nonEngAvgFinal = (res['nonEngFinalAvg'] as num).toDouble();
  if (engAvgFinal>0) { sumEngFinalPlayers += engAvgFinal; cntEngFinalPlayers++; }
  if (nonEngAvgFinal>0) { sumNonEngFinalPlayers += nonEngAvgFinal; cntNonEngFinalPlayers++; }
    // NEW: decay & position aggregation
    sumEngDecay += (res['engDecayPerMin'] as num).toDouble(); cntEngDecay++;
    sumNonEngDecay += (res['nonEngDecayPerMin'] as num).toDouble(); cntNonEngDecay++;
    sumEngGK += res['engPlayersGK'] as int; sumEngDEF += res['engPlayersDEF'] as int; sumEngMID += res['engPlayersMID'] as int; sumEngFWD += res['engPlayersFWD'] as int;
    final eGK = (res['engFinalGKAvg'] as num).toDouble(); if (eGK>0){ sumEngFinalGK += eGK; gamesWithEngGK++; }
    final eDEF = (res['engFinalDEFAvg'] as num).toDouble(); if (eDEF>0){ sumEngFinalDEF += eDEF; gamesWithEngDEF++; }
    final eMID = (res['engFinalMIDAvg'] as num).toDouble(); if (eMID>0){ sumEngFinalMID += eMID; gamesWithEngMID++; }
    final eFWD = (res['engFinalFWDAvg'] as num).toDouble(); if (eFWD>0){ sumEngFinalFWD += eFWD; gamesWithEngFWD++; }
    sumNonEngFinalGK += (res['nonEngFinalGKAvg'] as num).toDouble();
    sumNonEngFinalDEF += (res['nonEngFinalDEFAvg'] as num).toDouble();
    sumNonEngFinalMID += (res['nonEngFinalMIDAvg'] as num).toDouble();
    sumNonEngFinalFWD += (res['nonEngFinalFWDAvg'] as num).toDouble();
  }
  double avg(String k) => results.map((m) => (m[k] as num).toDouble()).fold(0.0, (a, b) => a + b) / results.length;
  final avgXg = avg('xgA') + avg('xgB');
  final avgGoals = avg('scoreA') + avg('scoreB');
  final passSuccessAll = totalAttemptsAll == 0 ? 0.0 : totalAllPass / totalAttemptsAll;
  final passSuccessShort = totalAttemptsShort==0?0.0: totalShort / totalAttemptsShort;
  final passSuccessLong = totalAttemptsLong==0?0.0: totalLong / totalAttemptsLong;
  final passSuccessBack = totalAttemptsBack==0?0.0: totalBack / totalAttemptsBack;
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
  final avgQ1 = nQ==0?0:sumQ1/nQ;
  final avgQ2 = nQ==0?0:sumQ2/nQ;
  final avgQ3 = nQ==0?0:sumQ3/nQ;
  final avgQ4 = nQ==0?0:sumQ4/nQ;
  final engAvg = nQ==0?0:sumEng/nQ;
  final nonEngAvg = nQ==0?0:sumNon/nQ;
  // NEW: aggregate computed metrics
  final engDecayAvg = cntEngDecay==0?0:sumEngDecay/cntEngDecay;
  final nonEngDecayAvg = cntNonEngDecay==0?0:sumNonEngDecay/cntNonEngDecay;
  final engReductionRel = (nonEngDecayAvg>0 && engDecayAvg>0)? 1 - (engDecayAvg/nonEngDecayAvg): 0;
  double avgOrZero(double sum, int cnt)=> cnt==0?0:sum/cnt;
  final engFinalGKAvg = avgOrZero(sumEngFinalGK, gamesWithEngGK);
  final engFinalDEFAvg = avgOrZero(sumEngFinalDEF, gamesWithEngDEF);
  final engFinalMIDAvg = avgOrZero(sumEngFinalMID, gamesWithEngMID);
  final engFinalFWDAvg = avgOrZero(sumEngFinalFWD, gamesWithEngFWD);
  final nonEngFinalGKAvg = avgOrZero(sumNonEngFinalGK, games);
  final nonEngFinalDEFAvg = avgOrZero(sumNonEngFinalDEF, games);
  final nonEngFinalMIDAvg = avgOrZero(sumNonEngFinalMID, games);
  final nonEngFinalFWDAvg = avgOrZero(sumNonEngFinalFWD, games);
  print('Games: $games  Mode: ${useGraph ? 'GRAPH' : 'LEGACY'}');
  print('Avg Goals: ${avgGoals.toStringAsFixed(2)}  Avg xG: ${avgXg.toStringAsFixed(2)}');
  print('Avg Shots: ${avg('shots').toStringAsFixed(1)}');
  print('Passes (short/long/back): $totalShort/$totalLong/$totalBack  Intercepts: $totalIntercepts');
  print('Pass Success (ALL): ${(passSuccessAll * 100).toStringAsFixed(1)}%  (passes=$totalAllPass, attempts=$totalAttemptsAll)');
  if (totalAttemptsShort>0) {
    print('Pass Success by type: short ${(passSuccessShort*100).toStringAsFixed(1)}% ($totalShort/$totalAttemptsShort)  long ${(passSuccessLong*100).toStringAsFixed(1)}% ($totalLong/$totalAttemptsLong)  back ${(passSuccessBack*100).toStringAsFixed(1)}% ($totalBack/$totalAttemptsBack)');
  }
  print('Pass Success (LEGACY short only): ${(passSuccessLegacy * 100).toStringAsFixed(1)}%  (passes=$totalLegacyPass, attempts=$totalLegacyAttempts)');
  print('Dribbles: attempts=$totalDribAtt success=$totalDribSucc fail=$totalDribFail  SuccessRate=${(dribbleSuccRate*100).toStringAsFixed(1)}%');
  print('Holds: $totalHolds  Launches: $totalLaunchAtt retain=$totalLaunchSucc fail=$totalLaunchFail  RetainRate=${(launchRetainRate*100).toStringAsFixed(1)}%');
  print('Ability Rosters avg (VIS/PAS/DRB/FIN/WALL/CAT/CAP): ${avgVisPlayers.toStringAsFixed(1)}/${avgPasPlayers.toStringAsFixed(1)}/${avgDrbPlayers.toStringAsFixed(1)}/${avgFinPlayers.toStringAsFixed(1)}/${avgWallPlayers.toStringAsFixed(1)}/${avgCatPlayers.toStringAsFixed(1)}/${avgCapPlayers.toStringAsFixed(1)}');
  print('FIN goals: $totalGoalsFin  CAT saves: $totalSavesCat (saveRate=${(catSaveRate*100).toStringAsFixed(1)}%)');
  print('DRB ability: attempts=$totalDrbAttDrb success=$totalDrbSuccDrb rate=${(drbAbilitySuccRate*100).toStringAsFixed(1)}%');
  print('PAS passes: short=$totalPassesPasShort (${(pasShareShort*100).toStringAsFixed(1)}% of all), long=$totalPassesPasLong (${(pasShareLong*100).toStringAsFixed(1)}% of long)');
  print('WALL intercept share: ${(wallInterceptShare*100).toStringAsFixed(1)}%  (wallIntercepts=$totalInterceptsWall of $totalIntercepts)');
  print('Stamina Q1/Q2/Q3/Q4 avg: ${avgQ1.toStringAsFixed(1)} / ${avgQ2.toStringAsFixed(1)} / ${avgQ3.toStringAsFixed(1)} / ${avgQ4.toStringAsFixed(1)}');
  final engAvgPlayers = cntEngFinalPlayers==0?0:sumEngFinalPlayers/cntEngFinalPlayers;
  final nonEngAvgPlayers = cntNonEngFinalPlayers==0?0:sumNonEngFinalPlayers/cntNonEngFinalPlayers;
  print('Final Stamina ENG vs non-ENG (game-level avg incl zeros): ${engAvg.toStringAsFixed(1)} vs ${nonEngAvg.toStringAsFixed(1)}');
  print('Final Stamina ENG vs non-ENG (player-only avg): ${engAvgPlayers.toStringAsFixed(1)} vs ${nonEngAvgPlayers.toStringAsFixed(1)} (diff ${(engAvgPlayers-nonEngAvgPlayers).toStringAsFixed(1)}pp)');
  // NEW prints
  print('ENG distribution (avg per game) GK/DEF/MID/FWD: ${(sumEngGK/games).toStringAsFixed(2)}/${(sumEngDEF/games).toStringAsFixed(2)}/${(sumEngMID/games).toStringAsFixed(2)}/${(sumEngFWD/games).toStringAsFixed(2)}');
  print('Per-pos final stamina ENG (GK/DEF/MID/FWD): ${engFinalGKAvg.toStringAsFixed(1)} / ${engFinalDEFAvg.toStringAsFixed(1)} / ${engFinalMIDAvg.toStringAsFixed(1)} / ${engFinalFWDAvg.toStringAsFixed(1)}');
  print('Per-pos final stamina non-ENG (GK/DEF/MID/FWD): ${nonEngFinalGKAvg.toStringAsFixed(1)} / ${nonEngFinalDEFAvg.toStringAsFixed(1)} / ${nonEngFinalMIDAvg.toStringAsFixed(1)} / ${nonEngFinalFWDAvg.toStringAsFixed(1)}');
  print('Avg stamina decay per minute ENG vs non-ENG: ${engDecayAvg.toStringAsFixed(3)} vs ${nonEngDecayAvg.toStringAsFixed(3)} (reduction ${(engReductionRel*100).toStringAsFixed(1)}%)');
}
