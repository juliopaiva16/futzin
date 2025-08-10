import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:futzin/domain/entities.dart';

/// Generates a deterministic pool of players (e.g. 1000) with attributes & abilities.
/// Output format: JSON lines (one player per line) OR a single JSON array (configurable).
/// This file will live under data/player_pool.jsonl (default) unless overridden.
/// We keep JSON (not YAML) for fastest parse in Dart + easier tooling.
///
/// Rationale: Large static pool allows sampling teams with known distribution for
/// strength differential experiments.
///
/// Usage:
///   dart run bin/simsets/generate_player_pool.dart --count 1000 --seed 42
///   dart run bin/simsets/generate_player_pool.dart --array > data/player_pool.json
///
/// Counts by macro position are balanced with adjustable ratios.
void main(List<String> args) async {
  int count = 1000;
  int seed = 42;
  bool asArray = false;
  String outPath = 'data/player_pool.jsonl';
  for (int i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--count' && i + 1 < args.length) { count = int.tryParse(args[++i]) ?? count; }
    else if (a == '--seed' && i + 1 < args.length) { seed = int.tryParse(args[++i]) ?? seed; }
    else if (a == '--array') { asArray = true; outPath = 'data/player_pool.json'; }
    else if (a == '--out' && i + 1 < args.length) { outPath = args[++i]; }
  }
  final r = Random(seed);
  final file = File(outPath);
  file.parent.createSync(recursive: true);

  // Position distribution target (approx). Always at least 1 GK per 16 players.
  // We'll assign positions in a repeating pattern to maintain ratio.
  final pattern = <Position>[];
  while (pattern.length < count) {
    pattern.add(Position.GK);
    for (int i=0;i<4;i++) pattern.add(Position.DEF);
    for (int i=0;i<6;i++) pattern.add(Position.MID);
    for (int i=0;i<5;i++) pattern.add(Position.FWD);
  }

  Player gen(int idx, Position pos) {
    int roll(int min, int max) => min + r.nextInt(max - min + 1);
    // Bias ranges by position lightly
    int attack, defense;
    switch (pos) {
      case Position.GK:
        attack = roll(25, 55); defense = roll(55, 90); break;
      case Position.DEF:
        attack = roll(30, 65); defense = roll(55, 95); break;
      case Position.MID:
        attack = roll(45, 85); defense = roll(40, 80); break;
      case Position.FWD:
        attack = roll(60, 95); defense = roll(25, 60); break;
    }
    final stamina = roll(55, 95);
    final pace = roll(40, 95);
    final passing = roll(40, 95);
    final technique = roll(40, 95);
    final strength = roll(35, 95);

    // Ability assignment probabilities (tweak later) - GK specific vs field
    final abilities = <String>{};
    double p() => r.nextDouble();
    if (pos != Position.GK && p() < 0.07) abilities.add('VIS');
    if (pos != Position.GK && p() < 0.07) abilities.add('PAS');
    if (pos != Position.GK && p() < 0.07) abilities.add('DRB');
    if (pos == Position.FWD && p() < 0.11) abilities.add('FIN');
    if (pos == Position.DEF && p() < 0.11) abilities.add('WALL');
    if (p() < 0.06) abilities.add('ENG');
    if (p() < 0.05) abilities.add('CAP');
    if (pos == Position.GK && p() < 0.30) abilities.add('CAT');
    // Placeholders for future abilities (currently inactive in engine)
    if (pos == Position.DEF && p() < 0.08) abilities.add('MRK');
    if (pos == Position.FWD && p() < 0.07) abilities.add('HDR');
    if (p() < 0.04) abilities.add('SPR');
    if (p() < 0.03) abilities.add('CLT');

    return Player(
      id: 'PL$idx',
      name: 'Player$idx',
      pos: pos,
      attack: attack,
      defense: defense,
      stamina: stamina,
      pace: pace,
      passing: passing,
      technique: technique,
      strength: strength,
      abilityCodes: abilities.take(3).toList(),
    );
  }

  final players = <Map<String,dynamic>>[];
  for (int i = 0; i < count; i++) {
    final pos = pattern[i];
    players.add(gen(i, pos).toJson());
  }

  if (asArray) {
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(players));
    stdout.writeln('Wrote ${players.length} players to $outPath (JSON array).');
  } else {
    final sink = file.openWrite();
    for (final p in players) { sink.writeln(jsonEncode(p)); }
    await sink.close();
    stdout.writeln('Wrote ${players.length} players to $outPath (JSONL).');
  }
}
