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
  const TeamConfigWidget({
    super.key,
    required this.title,
    required this.team,
    required this.onChanged,
    required this.simRunning,
    required this.onSubstitute,
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
                  onChanged: (f) {
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
            _tacticsSliders(t),
            const SizedBox(height: 8),
            Row(
              children: [
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
                const SizedBox(width: 12),
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
          onTap: () => _editPlayer(p),
          leading: Checkbox(
            value: selected,
            onChanged: (v) {
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
          subtitle: Text("ATK ${p.attack}  DEF ${p.defense}  STA ${p.stamina}"),
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

  Future<void> _editPlayer(Player p) async {
    int atk = p.attack;
    int def = p.defense;
    int sta = p.stamina;
    Position pos = p.pos;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit ${p.name}'),
          content: StatefulBuilder(
            builder: (ctx, setS) {
              return SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<Position>(
                      value: pos,
                      items: Position.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(positionLabel(e)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setS(() => pos = v ?? pos),
                    ),
                    const SizedBox(height: 8),
                    _sliderRow('ATK', atk, (v) => setS(() => atk = v)),
                    _sliderRow('DEF', def, (v) => setS(() => def = v)),
                    _sliderRow('STA', sta, (v) => setS(() => sta = v)),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  p.attack = atk;
                  p.defense = def;
                  p.stamina = sta;
                  p.pos = pos;
                  p.currentStamina = math.min(p.currentStamina, sta.toDouble());
                  widget.onChanged();
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _sliderRow(String label, int value, void Function(int) onChanged) {
    return Row(
      children: [
        SizedBox(width: 38, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 99,
            divisions: 98,
            label: value.toString(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 26, child: Text(value.toString())),
      ],
    );
  }

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
        height: 380,
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(l10n.onField),
                  Expanded(
                    child: ListView(
                      children: t.selected
                          .map(
                            (p) => RadioListTile<Player>(
                              value: p,
                              groupValue: outP,
                              onChanged: (v) => setState(() => outP = v),
                              title: Text(
                                '${p.name} (${positionLabel(p.pos)})',
                              ),
                              subtitle: Text(
                                'STA ${p.currentStamina.toStringAsFixed(0)}  YC ${p.yellowCards} ${p.injured ? l10n.statusInjured : ''} ${p.sentOff ? l10n.statusSentOff : ''}',
                              ),
                            ),
                          )
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
                          .map(
                            (p) => RadioListTile<Player>(
                              value: p,
                              groupValue: inP,
                              onChanged: (v) => setState(() => inP = v),
                              title: Text(
                                '${p.name} (${positionLabel(p.pos)})',
                              ),
                              subtitle: Text(
                                'ATK ${p.attack} DEF ${p.defense} STA ${p.stamina}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
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
