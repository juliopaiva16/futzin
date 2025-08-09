import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/app_localizations.dart';
import '../../domain/entities.dart';
import '../../domain/match_engine.dart';
import '../../domain/messages.dart';
import '../widgets/pitch_widget.dart';
import '../widgets/team_config_widget.dart';
import '../widgets/momentum_chart.dart';

/// Home page with team setup, live match view, and event log.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TeamConfig teamA;
  late TeamConfig teamB;

  MatchEngine? engine;
  final List<MatchEvent> events = [];
  final ScrollController _scroll = ScrollController();
  bool simRunning = false;
  bool loaded = false;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final sp = await SharedPreferences.getInstance();
    final data = sp.getString('futsim_state_v1');
    if (data != null) {
      try {
        final j = jsonDecode(data) as Map<String, dynamic>;
        teamA = TeamConfig.fromJson(j['teamA']);
        teamB = TeamConfig.fromJson(j['teamB']);
        loaded = true;
        setState(() {});
        return;
      } catch (_) {}
    }
    // fallback
    teamA = TeamConfig(
      name: 'Time A',
      formation: Formation.formations.first,
      tactics: Tactics(),
      squad: _generateSquad('A'),
    );
    teamB = TeamConfig(
      name: 'Time B',
      formation: Formation.formations[1],
      tactics: Tactics(
        attackBias: -0.1,
        tempo: 0.5,
        pressing: 0.6,
        lineHeight: 0.4,
      ),
      squad: _generateSquad('B'),
    );
    teamA.autoPick();
    teamB.autoPick();
    loaded = true;
    setState(() {});
  }

  Future<void> _saveState() async {
    final sp = await SharedPreferences.getInstance();
    final j = {'teamA': teamA.toJson(), 'teamB': teamB.toJson()};
    await sp.setString('futsim_state_v1', jsonEncode(j));
  }

  List<Player> _generateSquad(String tag) {
    final rng = Random(tag.hashCode);
    final namesGK = ['Rafael', 'Diego', 'Fábio', 'Murilo', 'Bruno'];
    final namesDEF = [
      'Carlos',
      'Henrique',
      'Naldo',
      'Tiago',
      'Sérgio',
      'Ramon',
      'Luiz',
      'Vitor',
    ];
    final namesMID = [
      'João',
      'Pedro',
      'Felipe',
      'Lucas',
      'André',
      'Gustavo',
      'Matheus',
      'Caio',
      'Danilo',
    ];
    final namesFWD = [
      'Paulo',
      'Ricardo',
      'Marcelo',
      'Wesley',
      'Renato',
      'Leandro',
    ];

    int r(int min, int max) => min + rng.nextInt(max - min + 1);
    String pid() => '${tag}_${rng.nextInt(1000000)}';

    final squad = <Player>[];

    for (int i = 0; i < 3; i++) {
      squad.add(
        Player(
          id: pid(),
          name: "${namesGK[i % namesGK.length]} $tag$i",
          pos: Position.GK,
          attack: r(20, 45),
          defense: r(65, 90),
          stamina: r(60, 90),
        ),
      );
    }
    for (int i = 0; i < 8; i++) {
      squad.add(
        Player(
          id: pid(),
          name: "${namesDEF[i % namesDEF.length]} $tag$i",
          pos: Position.DEF,
          attack: r(40, 70),
          defense: r(55, 90),
          stamina: r(60, 95),
        ),
      );
    }
    for (int i = 0; i < 8; i++) {
      squad.add(
        Player(
          id: pid(),
          name: "${namesMID[i % namesMID.length]} $tag$i",
          pos: Position.MID,
          attack: r(55, 85),
          defense: r(45, 80),
          stamina: r(65, 95),
        ),
      );
    }
    for (int i = 0; i < 6; i++) {
      squad.add(
        Player(
          id: pid(),
          name: "${namesFWD[i % namesFWD.length]} $tag$i",
          pos: Position.FWD,
          attack: r(65, 95),
          defense: r(35, 65),
          stamina: r(60, 90),
        ),
      );
    }

    return squad;
  }

  void _startMatch() async {
    final l10n = AppLocalizations.of(context)!;
    if (!teamA.isLineupValid || !teamB.isLineupValid) {
      _showSnack(l10n.invalidLineups);
      return;
    }
    await _saveState();
    setState(() {
      events.clear();
      engine?.stop();
      engine = MatchEngine(teamA, teamB, messages: _FlutterMatchMessages(l10n));
      simRunning = true;
    });
    engine!.stream.listen((e) {
      setState(() {
        events.add(e);
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
      if (e.text.contains(l10n.endMatch)) {
        setState(() => simRunning = false);
      }
    });
    engine!.start();
  }

  void _stopMatch() {
    engine?.stop();
    setState(() {
      simRunning = false;
    });
  }

  void _shareLog() {
    final l10n = AppLocalizations.of(context)!;
    if (events.isEmpty) {
      _showSnack(l10n.noEventsToExport);
      return;
    }
    final text = StringBuffer()
      ..writeln(
        '${teamA.name} ${events.last.scoreA} x ${events.last.scoreB} ${teamB.name}',
      )
      ..writeln(
        'xG: ${events.last.xgA.toStringAsFixed(2)} x ${events.last.xgB.toStringAsFixed(2)}',
      )
      ..writeln('---')
      ..writeAll(events.map((e) => e.text), '\n');
    SharePlus.instance.share(
      ShareParams(text: text.toString(), subject: l10n.exportLog),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final last = events.isNotEmpty ? events.last : null;
    final possA = (engine?.possA ?? 0.0);
    final possB = (engine?.possB ?? 0.0);
    final possTotal = (possA + possB).clamp(1.0, double.infinity);
    final possPctA = (100.0 * possA / possTotal);
    final possPctB = 100.0 - possPctA;

  final appBar = AppBar(
          title: Text(l10n.appTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: _shareLog,
              tooltip: l10n.exportLog,
            ),
            PopupMenuButton<double>(
              tooltip: 'Speed ${_speed}x',
              icon: const Icon(Icons.speed),
              onSelected: (v) {
                setState(() => _speed = v);
                engine?.setSpeed(v);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 1.0, child: Text('1x')),
                PopupMenuItem(value: 1.5, child: Text('1.5x')),
                PopupMenuItem(value: 2.0, child: Text('2x')),
                PopupMenuItem(value: 4.0, child: Text('4x')),
                PopupMenuItem(value: 10.0, child: Text('10x')),
              ],
            ),
            if (!simRunning)
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _startMatch,
                tooltip: l10n.startMatch,
              ),
            if (simRunning)
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _stopMatch,
                tooltip: l10n.stop,
              ),
          ],
    );

  Widget scoreboard() => Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${teamA.name} ${last?.scoreA ?? 0} x ${last?.scoreB ?? 0} ${teamB.name}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (events.isNotEmpty)
                        Text(
                          l10n.minuteShort((events.last.minute).toString()),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.possessionLabel}: ${possPctA.toStringAsFixed(0)}% x ${possPctB.toStringAsFixed(0)}%   '
                    '${l10n.xgLabel}: ${(last?.xgA ?? 0).toStringAsFixed(2)} x ${(last?.xgB ?? 0).toStringAsFixed(2)}',
                  ),
                ],
              ),
      );

    Widget pitchAndMomentum() => Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PitchWidget(teamA: teamA, teamB: teamB),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: MomentumChart(
                    events: events,
                    maxMinutes: 90,
                    height: 120,
                  ),
                ),
              ],
            );

    Widget eventsLog() => ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: events.length,
              itemBuilder: (ctx, i) {
                final e = events[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(e.text),
                );
              },
            );
    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          scoreboard(),
          // Pitch on top
          pitchAndMomentum(),
          // Team config below pitch
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TeamConfigWidget(
              title: teamA.name,
              team: teamA,
              simRunning: simRunning,
              onChanged: () async {
                setState(() {});
                await _saveState();
              },
              onSubstitute: (out, inn) {
                final ok = teamA.makeSub(out, inn);
                if (!ok) _showSnack('Invalid substitution');
                setState(() {});
              },
            ),
          ),
          if (!simRunning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: _startMatch,
                icon: const Icon(Icons.sports_soccer),
                label: Text(l10n.startButton),
              ),
            ),
          const Divider(height: 1),
          SizedBox(
            height: 320,
            child: eventsLog(),
          ),
        ],
      ),
    );
  }
}

class _FlutterMatchMessages implements MatchMessages {
  final AppLocalizations l10n;
  _FlutterMatchMessages(this.l10n);

  @override
  String calmMinute(int minute) => l10n.coolMinute(minute.toString());
  @override
  String kickoff() => l10n.kickoff;
  @override
  String endMatch() => l10n.endMatch;
  @override
  String recovery(String team, String player) =>
      '$team recovers the ball with $player.';

  // The following are placeholders while the engine is ported to use them.
  @override
  String anticipates(String team) =>
      '$team anticipates the play and avoids danger.';
  @override
  String deflectedOut() => 'Deflected out!';
  @override
  String defenseCloses(String team) => 'The $team backline closes the gaps.';
  @override
  String findsSpace(String player) =>
      '$player finds space and prepares the play!';
  @override
  String foulOn(String player) => 'Foul on $player.';
  @override
  String foulRed(String player, String team) => 'Red card for $player ($team).';
  @override
  String foulRedBrutal(String player, String team) =>
      'Horrible tackle! Red card for $player ($team).';
  @override
  String foulYellow(String player, String team) =>
      'Yellow card for $player ($team).';
  @override
  String injuryAfterChallenge(String player) =>
      'Oh no! $player feels after the challenge.';
  @override
  String injuryOutside(String player, String team) =>
      'Injury! $player ($team) goes down hurt.';
  @override
  String lateFoul(String team) => 'Referee spots a late foul by $team.';
  @override
  String pass(String from, String to) => '$from plays to $to.';
  @override
  String goal(String team, String player) => 'GOAL! $team scores with $player.';
  @override
  String savedByKeeper() => 'Saved by the keeper!';
  @override
  String offTarget() => 'Off target!';
  @override
  String shoots(String player) => '$player shoots!';
  @override
  String intercepted(String interceptor, String team) =>
      'Pass intercepted by $interceptor ($team).';
  @override
  String secondYellow(String player) => 'Second yellow! $player is sent off.';
  @override
  String subInjury(String team, String out, String inn) =>
      'Substitution $team: $out injured, $inn in.';
  @override
  String subTired(String team, String out, String inn) =>
      'Substitution $team: $out exhausted, $inn in.';
  @override
  String subYellowRisk(String team, String out, String inn) =>
      'Substitution $team: $out (booked) out, $inn in.';
}
