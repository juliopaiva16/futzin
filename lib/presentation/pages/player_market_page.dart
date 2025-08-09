import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';

import '../../domain/entities.dart';
// Removed edit dialog; using local painter for radar

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
  double _minPace = 50;
  double _minPassing = 50;
  double _minTechnique = 50;
  double _minStrength = 50;
  List<Player> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 250));

    final rng = Random(42 + (_pos?.index ?? 0));
    List<String> randAbilities(Position pos) {
      // GK-only CAT ability
      final pool = SpecialAbility.all
          .where((a) => a.code != 'CAT' || pos == Position.GK)
          .toList();
      final count = rng.nextInt(4); // 0..3 abilities
      pool.shuffle(rng);
      return pool.take(count).map((a) => a.code).toList();
    }
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
  pace: 40 + rng.nextInt(60),
  passing: 40 + rng.nextInt(60),
  technique: 40 + rng.nextInt(60),
  strength: 40 + rng.nextInt(60),
          abilityCodes: randAbilities(pos),
      );
    }).where((p) =>
        (p.attack >= _minAtk) &&
        (p.defense >= _minDef) &&
        (p.stamina >= _minSta) &&
    (p.pace >= _minPace) &&
    (p.passing >= _minPassing) &&
    (p.technique >= _minTechnique) &&
    (p.strength >= _minStrength) &&
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
  if (!mounted) return; // Ensure context is valid after async work
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
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<Position>(
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.filterPosition),
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
                const SizedBox(height: 12),
                // Core attributes
                _verticalStatSlider('ATK', _minAtk, (v) => setState(() => _minAtk = v)),
                _verticalStatSlider('DEF', _minDef, (v) => setState(() => _minDef = v)),
                _verticalStatSlider('STA', _minSta, (v) => setState(() => _minSta = v), min: 40),
                const Divider(height: 20),
                // Extended attributes
                _verticalStatSlider('PAC', _minPace, (v) => setState(() => _minPace = v)),
                _verticalStatSlider('PAS', _minPassing, (v) => setState(() => _minPassing = v)),
                _verticalStatSlider('TEC', _minTechnique, (v) => setState(() => _minTechnique = v)),
                _verticalStatSlider('STR', _minStrength, (v) => setState(() => _minStrength = v)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: Text(l10n.search),
                  ),
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
                        onTap: () => _showPlayerDetails(p, context),
                        leading: CircleAvatar(child: Text(positionShort(p.pos))),
                        title: Text(p.name),
                        subtitle: Text('ATK ${p.attack}  DEF ${p.defense}  STA ${p.stamina}  PAC ${p.pace} PAS ${p.passing} TEC ${p.technique} STR ${p.strength}'),
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

  Future<void> _showPlayerDetails(Player p, BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${p.name} (${positionLabel(p.pos)})'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 140,
                child: CustomPaint(
                  painter: _MarketPentagonPainter(values: [
                    p.attack.toDouble(),
                    p.pace.toDouble(),
                    p.passing.toDouble(),
                    p.technique.toDouble(),
                    p.strength.toDouble(),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Text('ATK ${p.attack}  DEF ${p.defense}  STA ${p.stamina}'),
              Text('PAC ${p.pace}  PAS ${p.passing}  TEC ${p.technique}  STR ${p.strength}'),
              const SizedBox(height: 8),
              const Text('Habilidades:'),
              if (p.abilities.isEmpty)
                const Text('No abilities', style: TextStyle(fontStyle: FontStyle.italic))
              else ...p.abilities.map((a) => Text('- ${a.name}: ${a.desc}', style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Widget _verticalStatSlider(String label, double value, void Function(double) onChanged, {double min = 0}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 44, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: 99,
                    divisions: 99 - min.toInt(),
                    label: value.toStringAsFixed(0),
                    onChanged: onChanged,
                  ),
                ),
              ),
              SizedBox(width: 34, child: Text(value.toStringAsFixed(0), textAlign: TextAlign.end)),
            ],
          ),
        ],
      ),
    );
  }

}

class _MarketPentagonPainter extends CustomPainter {
  final List<double> values;
  _MarketPentagonPainter({required this.values});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
  final radius = math.min(size.width, size.height) * 0.45;
    final grid = Paint()
      ..color = Colors.grey.withValues(alpha: 120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()
      ..color = Colors.blue.withValues(alpha: 90)
      ..style = PaintingStyle.fill;
    List<Offset> poly(double s) => List.generate(5, (i) {
          final angle = -math.pi / 2 + i * 2 * math.pi / 5;
          return center + Offset(math.cos(angle), math.sin(angle)) * radius * s;
        });
    for (final s in [1.0, 0.66, 0.33]) {
      final pts = poly(s);
      canvas.drawPath(Path()..addPolygon(pts, true), grid);
    }
    if (values.length == 5) {
      final pts = List.generate(5, (i) {
        final v = (values[i].clamp(0, 99)) / 99.0;
  final angle = -math.pi / 2 + i * 2 * math.pi / 5;
  return center + Offset(math.cos(angle), math.sin(angle)) * radius * v;
      });
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, grid);
    }
  }
  @override
  bool shouldRepaint(covariant _MarketPentagonPainter old) => old.values != values;

}
