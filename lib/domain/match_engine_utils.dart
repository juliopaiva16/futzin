part of 'match_engine.dart';

// Fatigue and ratings helpers extracted for modularity.
void _applyFatigue(TeamConfig t) {
  for (final p in t.selected) {
    if (p.sentOff || p.injured) continue;
    final base = 0.10; // per minute
    final tempo = t.tactics.tempo;
    final pressing = t.tactics.pressing;
    final fatigue = base + 0.35 * tempo + 0.25 * pressing;
    // Ability ENG reduces decay proportionally (relative reduction)
    final rel = p.hasAbility('ENG') ? (1 - EngineParams.graphAbilityEngStaminaDecayRel) : 1.0;
    final perMin = fatigue * rel;
    p.currentStamina = (p.currentStamina - perMin * 100 / 90).clamp(0, 100);
  }
}

_TeamRatings _teamRatings(TeamConfig t) {
  double eff(int base, double sta) => base * (0.60 + 0.40 * (sta / 100.0));
  final gk = t.selected.where((p) => p.pos == Position.GK && !p.sentOff && !p.injured).toList();
  final defs = t.selected.where((p) => p.pos == Position.DEF && !p.sentOff && !p.injured).toList();
  final mids = t.selected.where((p) => p.pos == Position.MID && !p.sentOff && !p.injured).toList();
  final fwds = t.selected.where((p) => p.pos == Position.FWD && !p.sentOff && !p.injured).toList();
  double avg(List<double> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;
  final gkD = gk.isNotEmpty ? eff(gk.first.defense, gk.first.currentStamina) : 40.0;
  final defD = avg(defs.map((p) => eff(p.defense, p.currentStamina)).toList());
  final defA = avg(defs.map((p) => eff(p.attack, p.currentStamina)).toList());
  final midD = avg(mids.map((p) => eff(p.defense, p.currentStamina)).toList());
  final midA = avg(mids.map((p) => eff(p.attack, p.currentStamina)).toList());
  final fwdA = avg(fwds.map((p) => eff(p.attack, p.currentStamina)).toList());
  final fwdD = avg(fwds.map((p) => eff(p.defense, p.currentStamina)).toList());
  double attack = fwdA * 1.0 + midA * 0.65 + defA * 0.2;
  double defense = defD * 1.0 + midD * 0.55 + gkD * 1.2 + fwdD * 0.1;
  final bias = t.tactics.attackBias; final pressing = t.tactics.pressing; final line = t.tactics.lineHeight; final width = t.tactics.width;
  attack *= (1.0 + 0.17 * bias + 0.05 * width);
  defense *= (1.0 - 0.11 * bias + 0.08 * (1.0 - width));
  defense += pressing * 6.0;
  attack *= (1.0 + 0.06 * line);
  defense *= (1.0 - 0.06 * line);
  // CAP ability small global buff (applied once if any CAP on field)
  if (t.selected.any((p) => p.hasAbility('CAP'))) {
    attack *= (1 + EngineParams.graphAbilityCapTeamAdj);
    defense *= (1 + EngineParams.graphAbilityCapTeamAdj);
  }
  return _TeamRatings(attackAdj: attack, defenseAdj: defense, gk: gk.isNotEmpty ? gk.first : null);
}
