import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';

import '../../domain/entities.dart';

class PlayerMarketPage extends StatefulWidget {
  const PlayerMarketPage({Key? key}) : super(key: key);

  @override
  State<PlayerMarketPage> createState() => _PlayerMarketPageState();
}

class _PlayerMarketPageState extends State<PlayerMarketPage> {
  Position? _pos;
  double _minAtk = 50;
  double _minDef = 50;
  double _minSta = 60;
  List<Player> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 250));

    final rng = Random(42 + (_pos?.index ?? 0));
    final List<Player> pool = List.generate(25, (i) {
      Position pos = _pos ?? Position.values[rng.nextInt(Position.values.length)];
      int atk = 30 + rng.nextInt(70);
      int def = 30 + rng.nextInt(70);
      int sta = 50 + rng.nextInt(50);
      return Player(
        id: 'MKT_${rng.nextInt(1000000)}',
        name: 'Jogador ${i + 1}',
        pos: pos,
        attack: atk,
        defense: def,
        stamina: sta,
      );
    }).where((p) =>
        (p.attack >= _minAtk) &&
        (p.defense >= _minDef) &&
        (p.stamina >= _minSta) &&
        (_pos == null || p.pos == _pos)).toList();

    setState(() {
      _results = pool;
      _loading = false;
    });
  }

  Future<void> _hire(Player p) async {
    final sp = await SharedPreferences.getInstance();
    TeamConfig? teamA;
    TeamConfig? teamB;
    final data = sp.getString('futsim_state_v1');
    if (data != null) {
      try {
        final j = jsonDecode(data) as Map<String, dynamic>;
        teamA = TeamConfig.fromJson(j['teamA']);
        teamB = TeamConfig.fromJson(j['teamB']);
      } catch (_) {}
    }
    teamA ??= TeamConfig(
      name: 'Time A',
      formation: Formation.formations.first,
      tactics: Tactics(),
      squad: [],
    );
    teamB ??= TeamConfig(
      name: 'Time B',
      formation: Formation.formations[1],
      tactics: Tactics(),
      squad: [],
    );
    // Prevent duplicate IDs
    if (!teamA.squad.any((e) => e.id == p.id)) {
      teamA.squad.add(p);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.name} contratado para ${teamA.name}!')),
      );
    }
    await sp.setString(
      'futsim_state_v1',
      jsonEncode({'teamA': teamA.toJson(), 'teamB': teamB.toJson()}),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.marketTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                DropdownButton<Position>(
                  hint: Text(l10n.filterPosition),
                  value: _pos,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.any),
                    ),
                    ...Position.values.map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(positionLabel(e)),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _pos = v),
                ),
                const SizedBox(width: 12),
                _statFilter('ATK', _minAtk, (v) => setState(() => _minAtk = v)),
                const SizedBox(width: 12),
                _statFilter('DEF', _minDef, (v) => setState(() => _minDef = v)),
                const SizedBox(width: 12),
                _statFilter('STA', _minSta, (v) => setState(() => _minSta = v), min: 40),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  label: Text(l10n.search),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text(positionShort(p.pos))),
                        title: Text(p.name),
                        subtitle: Text('ATK ${p.attack}  DEF ${p.defense}  STA ${p.stamina}'),
                        trailing: FilledButton(
                          onPressed: () => _hire(p),
                          child: Text(l10n.hire),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statFilter(String label, double value, void Function(double) onChanged, {double min = 0}) {
    return SizedBox(
      width: 160,
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: 99,
              divisions: 99 - min.toInt(),
              label: value.toStringAsFixed(0),
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 34, child: Text(value.toStringAsFixed(0))),
        ],
      ),
    );
  }
}
