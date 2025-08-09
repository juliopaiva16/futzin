part of 'match_engine.dart';

// Central effective attribute computation (Phase 6.3)
double _effectiveAttr(int base, double staminaPct) {
  // Original formula: base * (0.60 + 0.40 * staminaPct)
  // Hook for future abilities (B2B, SPR, SWS) and role modifiers if needed.
  final eff = base * (0.60 + 0.40 * staminaPct);
  return eff;
}

double _computeMinuteFatigue(Player p, TeamConfig t) {
  // Base minute cost scaled to 90' reference (legacy base 0.10)
  final tempo = t.tactics.tempo; // 0..1
  final pressing = t.tactics.pressing; // 0..1
  // Risk proxy: approximate share of risky actions from current tactics (using bias & width heuristics)
  final riskProxy = (t.tactics.attackBias.abs() * 0.5 + tempo * 0.3 + pressing * 0.2).clamp(0.0, 1.0);
  double cost = 0.08 // slightly lower baseline vs legacy 0.10
      + EngineParams.staminaTempoDecayFactor * tempo * 0.05
      + EngineParams.staminaPressingDecayFactor * pressing * 0.05
      + EngineParams.staminaRiskProxyFactor * riskProxy * 0.04; // each component scaled to keep total near previous
  // Clamp for stability
  cost = cost.clamp(0.05, 0.22);
  // ENG ability reduction (relative)
  if (p.hasAbility('ENG')) {
    cost *= (1 - EngineParams.graphAbilityEngStaminaDecayRel);
  }
  return cost; // per-minute fraction of 1.0 stamina scale (0..100 later scaled)
}

// Fatigue and ratings helpers extracted for modularity.
void _applyFatigue(TeamConfig t) {
  for (final p in t.selected) {
    if (p.sentOff || p.injured) continue;
    final perMin = _computeMinuteFatigue(p, t);
    p.currentStamina = (p.currentStamina - perMin * 100 / 90).clamp(0, 100);
  }
}

_TeamRatings _teamRatings(TeamConfig t) {
  // Replace local eff with central helper
  double eff(int base, double sta) => _effectiveAttr(base, sta / 100.0);
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
