import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';

import '../../domain/entities.dart';
import 'dart:math' as math; // for radar angles

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({super.key});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  TeamConfig? teamA;
  TeamConfig? teamB;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final data = sp.getString('futsim_state_v1');
    if (data != null) {
      try {
        final j = jsonDecode(data) as Map<String, dynamic>;
        teamA = TeamConfig.fromJson(j['teamA']);
        teamB = TeamConfig.fromJson(j['teamB']);
        // If squad accidentally persisted empty (older bug), regenerate basic squads so user can proceed.
        if (teamA!.squad.isEmpty) {
          teamA = TeamConfig(
            name: teamA!.name,
            formation: teamA!.formation,
            tactics: teamA!.tactics,
            squad: [],
          );
        }
        if (teamB!.squad.isEmpty) {
          teamB = TeamConfig(
            name: teamB!.name,
            formation: teamB!.formation,
            tactics: teamB!.tactics,
            squad: [],
          );
        }
        if (!teamA!.isLineupValid) teamA!.autoPick();
        if (!teamB!.isLineupValid) teamB!.autoPick();
      } catch (_) {}
    }
    teamA ??= TeamConfig(
      name: 'Time A',
      formation: Formation.formations.first,
      tactics: Tactics(),
      squad: [],
    )..autoPick();
    teamB ??= TeamConfig(
      name: 'Time B',
      formation: Formation.formations[1],
      tactics: Tactics(),
      squad: [],
    )..autoPick();
    setState(() => loading = false);
  }

  Future<void> _save() async {
    if (teamA == null || teamB == null) return;
    final sp = await SharedPreferences.getInstance();
    final j = {'teamA': teamA!.toJson(), 'teamB': teamB!.toJson()};
    await sp.setString('futsim_state_v1', jsonEncode(j));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.teamManagementTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: l10n.save,
          )
        ],
      ),
      body: _TeamManagementLayout(team: teamA!, onChanged: _save),
    );
  }
}

class _TeamManagementLayout extends StatefulWidget {
  final TeamConfig team;
  final VoidCallback onChanged;
  const _TeamManagementLayout({required this.team, required this.onChanged});
  @override
  State<_TeamManagementLayout> createState() => _TeamManagementLayoutState();
}

class _TeamManagementLayoutState extends State<_TeamManagementLayout> {
  // Players not related = those not in selectedIds or bench selection logic.
  // Here we treat selectedIds as starters (must be valid formation), bench as extra chosen bench list, rest = unassigned.
  final Set<String> benchIds = {}; // additional related (reserve) besides starters
  Player? selectedA;
  Player? selectedB;

  @override
  void initState() {
    super.initState();
    // Initialize bench with a heuristic: pick up to 9 best not selected.
    final remaining = widget.team.squad.where((p) => !widget.team.selectedIds.contains(p.id)).toList();
    remaining.sort((a,b)=> (b.attack+b.defense+b.stamina).compareTo(a.attack+a.defense+a.stamina));
    benchIds.addAll(remaining.take(9).map((e)=>e.id));
  }

  List<Player> get starters => widget.team.selected;
  List<Player> get bench => widget.team.squad.where((p)=> benchIds.contains(p.id)).toList();
  List<Player> get unassigned => widget.team.squad.where((p)=> !widget.team.selectedIds.contains(p.id) && !benchIds.contains(p.id)).toList();

  // (old _move helper removed after interaction redesign)

  Color _zoneColor(String key) {
    switch (key) {
      case 'starters': return Colors.green.withValues(alpha: 30);
      case 'bench': return Colors.blue.withValues(alpha: 30);
      case 'unassigned': return Colors.grey.withValues(alpha: 25);
    }
    return Colors.grey.withValues(alpha: 20);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
  _tacticsCard(l10n),
  if (selectedA != null) const SizedBox(height: 12),
  if (selectedA != null) _comparisonPanel(),
  const SizedBox(height: 12),
        _sectionHeader('${l10n.onField} (${starters.length}/11)'),
        _zoneList('starters', starters),
        const SizedBox(height: 12),
        _sectionHeader('${l10n.bench} (${bench.length})'),
        _zoneList('bench', bench),
        const SizedBox(height: 12),
        _sectionHeader('Elenco (não relacionados) (${unassigned.length})'),
        _zoneList('unassigned', unassigned),
        const SizedBox(height: 16),
        Text(widget.team.isLineupValid ? l10n.validLineup : l10n.incompleteLineup, style: TextStyle(color: widget.team.isLineupValid? Colors.green: Colors.red)),
      ],
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  Widget _zoneList(String key, List<Player> players) {
    return Container(
      decoration: BoxDecoration(
        color: _zoneColor(key),
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: players.isEmpty
          ? const SizedBox(height: 48, child: Center(child: Text('Vazio')))
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: players.map((p) => _playerChip(p, key)).toList(),
            ),
    );
  }

  Widget _playerChip(Player p, String currentZone) {
    final isStarter = widget.team.selectedIds.contains(p.id);
    final isBench = benchIds.contains(p.id);
    final isSel = p == selectedA || p == selectedB;
    return GestureDetector(
      onTap: () => _onSelectPlayer(p),
      child: _chipContent(
        p,
        highlight: isSel,
        labelExtra: isStarter ? 'S' : isBench ? 'B' : '',
      ),
    );
  }

  Widget _chipContent(Player p, {bool highlight=false, String labelExtra=''}) {
    final total = p.attack + p.defense + p.stamina;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
  color: highlight ? Colors.amber.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
        boxShadow: highlight ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(positionShort(p.pos), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width:4),
          Text(p.name.split(' ').first),
          const SizedBox(width:6),
          Text(total.toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if(labelExtra.isNotEmpty) ...[
            const SizedBox(width:4),
            Container(padding: const EdgeInsets.symmetric(horizontal:4, vertical:2), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)), child: Text(labelExtra, style: const TextStyle(fontSize:10)))
          ]
        ],
      ),
    );
  }

  // (old _showDetails dialog removed; details now shown via other screens if needed)
  // Selection handling
  void _onSelectPlayer(Player p) {
    setState(() {
      if (selectedA == null || (selectedA != null && selectedB != null)) {
        // start new selection cycle
        selectedA = p;
        selectedB = null;
      } else if (selectedA == p) {
        // deselect primary
        selectedA = null;
        selectedB = null;
      } else if (selectedB == p) {
        // deselect secondary
        selectedB = null;
      } else {
        // set second
        selectedB = p;
      }
    });
  }

  void _swapSelected() {
    final a = selectedA; final b = selectedB;
    if (a == null || b == null) return;
    // Determine zones
    String zone(Player p) => widget.team.selectedIds.contains(p.id) ? 'starters' : (benchIds.contains(p.id) ? 'bench' : 'unassigned');
    final za = zone(a);
    final zb = zone(b);
    // If both same zone, nothing
    if (za == zb) return;
    setState(() {
      // Remove both
      if (za == 'starters') {
        widget.team.selectedIds.remove(a.id);
      } else if (za == 'bench') benchIds.remove(a.id);
      if (zb == 'starters') {
        widget.team.selectedIds.remove(b.id);
      } else if (zb == 'bench') benchIds.remove(b.id);
      // Try add swapped
      bool ok = true;
      if (za == 'starters') {
        if (widget.team.canSelect(b)) {
          widget.team.selectedIds.add(b.id);
        } else { ok = false; }
      } else if (za == 'bench') { benchIds.add(b.id); }
      else { /* unassigned -> nothing extra */ }
      if (zb == 'starters') {
        if (widget.team.canSelect(a)) {
          widget.team.selectedIds.add(a.id);
        } else { ok = false; }
      } else if (zb == 'bench') { benchIds.add(a.id); }
      if (!ok) {
        // revert if failed
        // Clear sets and re-add original membership
        widget.team.selectedIds.remove(b.id); benchIds.remove(b.id);
        widget.team.selectedIds.remove(a.id); benchIds.remove(a.id);
        if (za == 'starters') {
          widget.team.selectedIds.add(a.id);
        } else if (za == 'bench') benchIds.add(a.id);
        if (zb == 'starters') {
          widget.team.selectedIds.add(b.id);
        } else if (zb == 'bench') benchIds.add(b.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Troca inválida para a formação.')));
      } else {
        widget.onChanged();
      }
    });
  }

  Widget _tacticsCard(AppLocalizations l10n) {
    final t = widget.team.tactics;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.formation),
                const SizedBox(width: 8),
                DropdownButton<Formation>(
                  value: widget.team.formation,
                  items: Formation.formations
                      .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                      .toList(),
                  onChanged: (f) {
                    if (f == null) return;
                    setState(() {
                      widget.team.formation = f;
                      widget.team.autoPick();
                      widget.onChanged();
                    });
                  },
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    setState(() { widget.team.autoPick(); widget.onChanged(); });
                  },
                  child: Text(l10n.autoPick),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _sliderRow(l10n.labelBias, t.attackBias, -1, 1, (v){ setState(()=> widget.team.tactics = t.copyWith(attackBias: v)); widget.onChanged(); }),
            _sliderRow(l10n.labelTempo, t.tempo, 0, 1, (v){ setState(()=> widget.team.tactics = t.copyWith(tempo: v)); widget.onChanged(); }),
            _sliderRow(l10n.labelPressing, t.pressing, 0, 1, (v){ setState(()=> widget.team.tactics = t.copyWith(pressing: v)); widget.onChanged(); }),
            _sliderRow(l10n.labelLine, t.lineHeight, 0, 1, (v){ setState(()=> widget.team.tactics = t.copyWith(lineHeight: v)); widget.onChanged(); }),
            _sliderRow(l10n.labelWidth, t.width, 0, 1, (v){ setState(()=> widget.team.tactics = t.copyWith(width: v)); widget.onChanged(); }),
          ],
        ),
      ),
    );
  }

  Widget _comparisonPanel() {
    final a = selectedA!;
    final b = selectedB;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(b == null ? 'Comparação: ${a.name}' : 'Comparação: ${a.name} vs ${b.name}')),
            if (selectedA != null && selectedB != null)
              IconButton(
                tooltip: 'Trocar',
                onPressed: _swapSelected,
                icon: const Icon(Icons.swap_horiz),
              ),
          ],
        ),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _ComparePentagonPainter(
              aVals: [a.attack, a.pace, a.passing, a.technique, a.strength].map((e)=> e.toDouble()).toList(),
              bVals: b == null ? null : [b.attack, b.pace, b.passing, b.technique, b.strength].map((e)=> e.toDouble()).toList(),
            ),
            child: Center(
              child: Text('ATK PAC PAS TEC STR', style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComparePentagonPainter extends CustomPainter {
  final List<double> aVals;
  final List<double>? bVals;
  _ComparePentagonPainter({required this.aVals, required this.bVals});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.45;
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final s in [1.0, 0.66, 0.33]) {
      final pts = List.generate(5, (i) {
        final ang = -math.pi / 2 + i * 2 * math.pi / 5;
        return center + Offset(math.cos(ang), math.sin(ang)) * radius * s;
      });
      canvas.drawPath(Path()..addPolygon(pts, true), gridPaint);
    }
    List<Offset> poly(List<double> vals) => List.generate(5, (i) {
          final ang = -math.pi / 2 + i * 2 * math.pi / 5;
          final v = (vals[i].clamp(0, 99)) / 99.0;
          return center + Offset(math.cos(ang), math.sin(ang)) * radius * v;
        });
    final aPath = Path()..addPolygon(poly(aVals), true);
    canvas.drawPath(aPath, Paint()..color = Colors.blue.withValues(alpha: 90));
    canvas.drawPath(
        aPath,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    if (bVals != null) {
      final bPath = Path()..addPolygon(poly(bVals!), true);
      canvas.drawPath(bPath, Paint()..color = Colors.red.withValues(alpha: 90));
      canvas.drawPath(
          bPath,
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _ComparePentagonPainter old) => old.aVals != aVals || old.bVals != bVals;
}

extension _SliderRowExt on _TeamManagementLayoutState {
  Widget _sliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 10,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
