/// Player generation factory (MT2) providing correlated attributes.
/// Extracted from original bin generator to enable unit tests and reuse.
import 'dart:math';
import 'entities.dart';

class PlayerFactoryConfig {
  final int attackMin;
  final int attackMax;
  final int defenseMin;
  final int defenseMax;
  const PlayerFactoryConfig({required this.attackMin,required this.attackMax,required this.defenseMin,required this.defenseMax});
}

PlayerFactoryConfig _rangeFor(Position pos) {
  switch (pos) {
    case Position.GK: return const PlayerFactoryConfig(attackMin:25,attackMax:55, defenseMin:55, defenseMax:90);
    case Position.DEF: return const PlayerFactoryConfig(attackMin:30,attackMax:65, defenseMin:55, defenseMax:95);
    case Position.MID: return const PlayerFactoryConfig(attackMin:45,attackMax:85, defenseMin:40, defenseMax:80);
    case Position.FWD: return const PlayerFactoryConfig(attackMin:60,attackMax:95, defenseMin:25, defenseMax:60);
  }
}

int _roll(Random r, int min, int max) => min + r.nextInt(max - min + 1);

class GeneratedPlayerData {
  final Player player;
  final int tier;
  GeneratedPlayerData(this.player, this.tier);
}

GeneratedPlayerData generatePlayer({required int index, required Position pos, required Random rng}) {
  final range = _rangeFor(pos);
  int attack = _roll(rng, range.attackMin, range.attackMax);
  int defense = _roll(rng, range.defenseMin, range.defenseMax);
  // Preliminary quality score for tier assignment (before buffs)
  final quality = (attack + defense) / 2.0;
  int tier; if (quality >= 85) tier = 1; else if (quality >= 75) tier = 2; else if (quality >= 63) tier = 3; else tier = 4;
  // Height & preferred foot
  int baseH; switch (pos) {
    case Position.GK: baseH = 188; break; case Position.DEF: baseH = 184; break; case Position.MID: baseH = 178; break; case Position.FWD: baseH = 181; break;
  }
  final height = baseH + _roll(rng, -6, 6);
  final rf = rng.nextDouble();
  String foot = rf < 0.78 ? 'R' : (rf < 0.96 ? 'L' : 'B');
  // Base secondary attributes
  int stamina = _roll(rng, 55, 95);
  int pace = _roll(rng, 40, 95);
  int passing = _roll(rng, 40, 95);
  int technique = _roll(rng, 40, 95);
  int strength = _roll(rng, 35, 95);
  // Correlations:
  // - Tier boosts: higher tiers get +delta on core + some on secondaries (diminishing)
  double tierScale(int t, double a, double b, double c) { // piecewise helper
    switch (t) { case 1: return c; case 2: return b; case 3: return a; default: return 0; }
  }
  int clampAttr(int v) => v.clamp(20, 99);
  final atkBoost = tierScale(tier, 2, 4, 6).round();
  final defBoost = tierScale(tier, 2, 4, 6).round();
  attack = clampAttr(attack + atkBoost);
  defense = clampAttr(defense + defBoost);
  stamina = clampAttr(stamina + tierScale(tier, 1, 2, 3).round());
  passing = clampAttr(passing + tierScale(tier, 1, 3, 5).round());
  technique = clampAttr(technique + tierScale(tier, 1, 2, 4).round());
  // Foot influence: Left slight passing/tech boost; Both moderate all-round; Right slight pace bias
  if (foot == 'L') { passing = clampAttr(passing + 3); technique = clampAttr(technique + 2); }
  else if (foot == 'B') { passing = clampAttr(passing + 2); technique = clampAttr(technique + 1); pace = clampAttr(pace + 1); }
  else { pace = clampAttr(pace + 1); }
  // Height to strength correlation (± up to 4 based on deviation from 180 baseline)
  strength = clampAttr(strength + ((height - 180) / 5).round());
  // Assign abilities (same logic as original, kept here to ensure deterministic pipeline)
  final abilities = <String>{}; double p() => rng.nextDouble();
  if (pos != Position.GK && p() < 0.07) abilities.add('VIS');
  if (pos != Position.GK && p() < 0.07) abilities.add('PAS');
  if (pos != Position.GK && p() < 0.07) abilities.add('DRB');
  if (pos == Position.FWD && p() < 0.11) abilities.add('FIN');
  if (pos == Position.DEF && p() < 0.11) abilities.add('WALL');
  if (p() < 0.06) abilities.add('ENG');
  if (p() < 0.05) abilities.add('CAP');
  if (pos == Position.GK && p() < 0.30) abilities.add('CAT');
  if (pos == Position.DEF && p() < 0.08) abilities.add('MRK');
  if (pos == Position.FWD && p() < 0.07) abilities.add('HDR');
  if (p() < 0.04) abilities.add('SPR');
  if (p() < 0.03) abilities.add('CLT');
  // Build Player
  final player = Player(
    id:'PL$index', name:'Player$index', pos: pos,
    attack: attack, defense: defense, stamina: stamina,
    pace: pace, passing: passing, technique: technique, strength: strength,
    abilityCodes: abilities.take(3).toList(), heightCm: height, preferredFoot: foot, tier: tier,
  );
  return GeneratedPlayerData(player, tier);
}
