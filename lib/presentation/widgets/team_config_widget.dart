import '../../core/localization/app_localizations.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities.dart';

/// Team configuration panel with formation, tactics, and squad list.
class TeamConfigWidget extends StatefulWidget {
  final String title;
  final TeamConfig team;
  final bool simRunning;
  final VoidCallback onChanged;
  final void Function(Player out, Player inn) onSubstitute;
  final bool readOnly; // when true, all editing is disabled
  const TeamConfigWidget({
    super.key,
    required this.title,
    required this.team,
    required this.onChanged,
    required this.simRunning,
    required this.onSubstitute,
    this.readOnly = false,
  });

  @override
  State<TeamConfigWidget> createState() => _TeamConfigWidgetState();
}

class _TeamConfigWidgetState extends State<TeamConfigWidget> {
  @override
  Widget build(BuildContext context) {
    final t = widget.team;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Text(widget.title, style: theme.textTheme.titleLarge),
                const Spacer(),
                if (!widget.readOnly)
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: TextEditingController(text: t.name),
                      decoration: InputDecoration(labelText: l10n.teamName),
                      onChanged: (v) {
                        t.name = v;
                        widget.onChanged();
                      },
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(t.name, style: theme.textTheme.titleMedium),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.formation),
                const SizedBox(width: 8),
                DropdownButton<Formation>(
                  value: t.formation,
                  items: Formation.formations
                      .map(
                        (f) => DropdownMenuItem(value: f, child: Text(f.name)),
                      )
                      .toList(),
                  onChanged: widget.readOnly
                      ? null
                      : (f) {
                          if (f == null) return;
                          setState(() {
                            t.formation = f;
                            t.autoPick();
                            widget.onChanged();
                          });
                        },
                ),
                const Spacer(),
                Text(
                  'GK ${t.selectedGK}/1   DEF ${t.selectedDEF}/${t.needDEF}   MID ${t.selectedMID}/${t.needMID}   FWD ${t.selectedFWD}/${t.needFWD}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!widget.readOnly) _tacticsSliders(t),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!widget.readOnly)
                  FilledButton(
                    onPressed: widget.simRunning
                        ? null
                        : () {
                            setState(() {
                              t.autoPick();
                              widget.onChanged();
                            });
                          },
                    child: Text(l10n.autoPick),
                  ),
                if (!widget.readOnly) const SizedBox(width: 12),
                if (!widget.readOnly)
                  OutlinedButton.icon(
                    onPressed: () => _openSubsDialog(t),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l10n.subs(t.subsLeft)),
                  ),
                const SizedBox(width: 12),
                Text(
                  t.isLineupValid ? l10n.validLineup : l10n.incompleteLineup,
                  style: TextStyle(
                    color: t.isLineupValid ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(),
            SizedBox(height: 280, child: _squadList(t)),
          ],
        ),
      ),
    );
  }

  Widget _tacticsSliders(TeamConfig t) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 90, child: Text(l10n.labelBias)),
            Expanded(
              child: Slider(
                value: t.tactics.attackBias,
                min: -1,
                max: 1,
                divisions: 8,
                label: t.tactics.attackBias.toStringAsFixed(2),
                onChanged: (v) {
                  setState(() {
                    t.tactics = t.tactics.copyWith(attackBias: v);
                    widget.onChanged();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.defensive),
            const SizedBox(width: 6),
            const Icon(Icons.compare_arrows, size: 16),
            const SizedBox(width: 6),
            Text(l10n.offensive),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 90, child: Text(l10n.labelTempo)),
            Expanded(
              child: Slider(
                value: t.tactics.tempo,
                min: 0,
                max: 1,
                divisions: 10,
                label: t.tactics.tempo.toStringAsFixed(2),
                onChanged: (v) {
                  setState(() {
                    t.tactics = t.tactics.copyWith(tempo: v);
                    widget.onChanged();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.low),
            const SizedBox(width: 6),
            const Icon(Icons.speed, size: 16),
            const SizedBox(width: 6),
            Text(l10n.high),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 90, child: Text(l10n.labelPressing)),
            Expanded(
              child: Slider(
                value: t.tactics.pressing,
                min: 0,
                max: 1,
                divisions: 10,
                label: t.tactics.pressing.toStringAsFixed(2),
                onChanged: (v) {
                  setState(() {
                    t.tactics = t.tactics.copyWith(pressing: v);
                    widget.onChanged();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.low),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_upward, size: 16),
            const SizedBox(width: 6),
            Text(l10n.high),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 90, child: Text(l10n.labelLine)),
            Expanded(
              child: Slider(
                value: t.tactics.lineHeight,
                min: 0,
                max: 1,
                divisions: 10,
                label: t.tactics.lineHeight.toStringAsFixed(2),
                onChanged: (v) {
                  setState(() {
                    t.tactics = t.tactics.copyWith(lineHeight: v);
                    widget.onChanged();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.low),
            const SizedBox(width: 6),
            const Icon(Icons.vertical_align_top, size: 16),
            const SizedBox(width: 6),
            Text(l10n.high),
          ],
        ),
        // Width slider (if present in tactics)
        Row(
          children: [
            SizedBox(width: 90, child: Text(l10n.labelWidth)),
            Expanded(
              child: Slider(
                value: t.tactics.width,
                min: 0,
                max: 1,
                divisions: 10,
                label: t.tactics.width.toStringAsFixed(2),
                onChanged: (v) {
                  setState(() {
                    t.tactics = t.tactics.copyWith(width: v);
                    widget.onChanged();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.narrow),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_full, size: 16),
            const SizedBox(width: 6),
            Text(l10n.wide),
          ],
        ),
      ],
    );
  }

  Widget _squadList(TeamConfig t) {
    final sorted = [...t.squad];
    sorted.sort((a, b) {
      int posOrder(Position p) {
        switch (p) {
          case Position.GK:
            return 0;
          case Position.DEF:
            return 1;
          case Position.MID:
            return 2;
          case Position.FWD:
            return 3;
        }
      }

      final d = posOrder(a.pos).compareTo(posOrder(b.pos));
      if (d != 0) return d;
      return (b.attack + b.defense + b.stamina).compareTo(
        a.attack + a.defense + a.stamina,
      );
    });

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final p = sorted[i];
        final selected = t.selectedIds.contains(p.id);
        final status = p.sentOff
            ? 'OFF'
            : p.injured
            ? 'INJ'
            : '';
        return ListTile(
          onTap: () => _showPlayerDetails(p),
          leading: Checkbox(
            value: selected,
            onChanged: widget.readOnly
                ? null
                : (v) {
                    setState(() {
                      if (v == true) {
                        if (t.canSelect(p)) {
                          t.selectedIds.add(p.id);
                        }
                      } else {
                        t.selectedIds.remove(p.id);
                      }
                      widget.onChanged();
                    });
                  },
          ),
          title: Text(
            "${p.name} (${positionLabel(p.pos)}) ${status.isNotEmpty ? '[$status]' : ''}",
          ),
          subtitle: Text("ATK ${p.attack}  DEF ${p.defense}  STA ${p.stamina}  PAC ${p.pace} PAS ${p.passing} TEC ${p.technique} STR ${p.strength}"),
          trailing: selected
              ? Text(
                  "STA ${p.currentStamina.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: p.currentStamina < 30 ? Colors.orange : Colors.grey,
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _showPlayerDetails(Player p) async {
    final l10n = AppLocalizations.of(context)!;
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
                  painter: _PentagonPainter(values: [
                    p.attack.toDouble(),
                    p.pace.toDouble(),
                    p.passing.toDouble(),
                    p.technique.toDouble(),
                    p.strength.toDouble(),
                  ]),
                  child: const Center(child: Text('')),
                ),
              ),
              const SizedBox(height: 8),
              Text('ATK ${p.attack}  DEF ${p.defense}  STA ${p.stamina}'),
              Text('PAC ${p.pace}  PAS ${p.passing}  TEC ${p.technique}  STR ${p.strength}'),
              const SizedBox(height: 8),
              Text('Habilidades:'),
              if (p.abilities.isEmpty)
                const Text('No abilities', style: TextStyle(fontStyle: FontStyle.italic))
              else ...p.abilities.map((a) => Text('- ${a.name}: ${a.desc}', style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))
        ],
      ),
    );
  }

  // _sliderRow removed (editing disabled)

  Future<void> _openSubsDialog(TeamConfig t) async {
    await showDialog(
      context: context,
      builder: (ctx) => SubDialog(team: t, onSubstitute: widget.onSubstitute),
    );
    setState(() {});
    widget.onChanged();
  }
}

class SubDialog extends StatefulWidget {
  final TeamConfig team;
  final void Function(Player out, Player inn) onSubstitute;
  const SubDialog({super.key, required this.team, required this.onSubstitute});

  @override
  State<SubDialog> createState() => _SubDialogState();
}

class _PentagonPainter extends CustomPainter {
  final List<double> values; // expect length 5, 0-99
  _PentagonPainter({required this.values});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.45;
    final paintGrid = Paint()
      ..color = Colors.grey.withValues(alpha: 120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final paintFill = Paint()
      ..color = Colors.blue.withValues(alpha: 90)
      ..style = PaintingStyle.fill;

    List<Offset> polygon(double scale) {
      return List.generate(5, (i) {
        final angle = -math.pi / 2 + i * 2 * math.pi / 5;
        return center + Offset(math.cos(angle), math.sin(angle)) * radius * scale;
      });
    }

    // Draw 3 concentric pentagons
    for (final s in [1.0, 0.66, 0.33]) {
      final pts = polygon(s);
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, paintGrid);
    }

    // Data polygon
    if (values.length == 5) {
      final pts = List.generate(5, (i) {
        final v = (values[i].clamp(0, 99)) / 99.0;
        final angle = -math.pi / 2 + i * 2 * math.pi / 5;
        return center + Offset(math.cos(angle), math.sin(angle)) * radius * v;
      });
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, paintFill);
      canvas.drawPath(path, paintGrid);
    }
  }

  @override
  bool shouldRepaint(covariant _PentagonPainter oldDelegate) => oldDelegate.values != values;
}

class _SubDialogState extends State<SubDialog> {
  Player? outP;
  Player? inP;

  @override
  Widget build(BuildContext context) {
    final t = widget.team;
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.subsDialogTitle(t.name, t.subsLeft)),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            // Selection lists
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(l10n.onField),
                        Expanded(
                          child: ListView(
                            children: t.selected
                                .map((p) => RadioListTile<Player>(
                                      value: p,
                                      groupValue: outP,
                                      onChanged: (v) => setState(() => outP = v),
                                      title: Text('${p.name} (${positionLabel(p.pos)})'),
                                      subtitle: Text('STA ${p.currentStamina.toStringAsFixed(0)}'),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(),
                  Expanded(
                    child: Column(
                      children: [
                        Text(l10n.bench),
                        Expanded(
                          child: ListView(
                            children: t.bench
                                .map((p) => RadioListTile<Player>(
                                      value: p,
                                      groupValue: inP,
                                      onChanged: (v) => setState(() => inP = v),
                                      title: Text('${p.name} (${positionLabel(p.pos)})'),
                                      subtitle: Text('ATK ${p.attack} DEF ${p.defense} STA ${p.stamina}'),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (outP != null && inP != null)
              _SubComparison(out: outP!, inn: inP!),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
        FilledButton(
          onPressed: (outP != null && inP != null && t.subsLeft > 0)
              ? () {
                  widget.onSubstitute(outP!, inP!);
                  setState(() {
                    outP = null;
                    inP = null;
                  });
                }
              : null,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class _SubComparison extends StatelessWidget {
  final Player out;
  final Player inn;
  const _SubComparison({required this.out, required this.inn});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              const Icon(Icons.arrow_downward, color: Colors.red, size: 16),
              const SizedBox(width:4),
              const Text('OUT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ]),
            Row(children: [
              const Icon(Icons.arrow_upward, color: Colors.blue, size: 16),
              const SizedBox(width:4),
              const Text('IN', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _DualPentagonPainter(outP: out, inP: inn),
            child: Center(
              child: Text('${out.name.split(' ').first} → ${inn.name.split(' ').first}', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DualPentagonPainter extends CustomPainter {
  final Player outP;
  final Player inP;
  _DualPentagonPainter({required this.outP, required this.inP});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.45;
    List<Offset> poly(List<double> vals) {
      return List.generate(5, (i) {
        final angle = -math.pi / 2 + i * 2 * math.pi / 5;
        final v = (vals[i].clamp(0, 99)) / 99.0;
        return center + Offset(math.cos(angle), math.sin(angle)) * radius * v;
      });
    }
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final s in [1.0, 0.66, 0.33]) {
      final pts = List.generate(5, (i) {
        final angle = -math.pi / 2 + i * 2 * math.pi / 5;
        return center + Offset(math.cos(angle), math.sin(angle)) * radius * s;
      });
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, gridPaint);
    }
    final outVals = [outP.attack, outP.pace, outP.passing, outP.technique, outP.strength].map((e)=>e.toDouble()).toList();
    final inVals = [inP.attack, inP.pace, inP.passing, inP.technique, inP.strength].map((e)=>e.toDouble()).toList();
    final outPath = Path()..addPolygon(poly(outVals), true);
    final inPath = Path()..addPolygon(poly(inVals), true);
    canvas.drawPath(outPath, Paint()..color = Colors.red.withValues(alpha: 90));
    canvas.drawPath(inPath, Paint()..color = Colors.blue.withValues(alpha: 90));
    canvas.drawPath(outPath, Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawPath(inPath, Paint()..color = Colors.blue..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(covariant _DualPentagonPainter oldDelegate) => oldDelegate.outP != outP || oldDelegate.inP != inP;
}
