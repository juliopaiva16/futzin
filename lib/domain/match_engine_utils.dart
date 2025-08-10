part of 'match_engine.dart';

// Central effective attribute computation (Phase 6.3)
// --- Attribute & Role Helpers -------------------------------------------------

/// Role multipliers for attack/defense (per player) extracted from docs.
/// Values kept modest to avoid destabilizing existing tuning; may be retuned.
class _RoleMods { final double atk; final double def; final double width; const _RoleMods(this.atk,this.def,this.width); }

_RoleMods _roleMods(Role r) {
  switch (r) {
    case Role.DEF_CB: return const _RoleMods(1.00, 1.05, 0.00);
    case Role.DEF_STP: return const _RoleMods(1.00, 1.07, 0.00);
    case Role.DEF_LIB: return const _RoleMods(1.02, 0.98, 0.00);
    case Role.DEF_FBW: return const _RoleMods(1.03, 0.97, 0.01);
    case Role.DEF_FBD: return const _RoleMods(0.98, 1.04, 0.00);
    case Role.MID_ANC: return const _RoleMods(0.97, 1.06, 0.00);
    case Role.MID_B2B: return const _RoleMods(1.02, 1.02, 0.00);
    case Role.MID_CM: return const _RoleMods(1.00, 1.00, 0.00);
    case Role.MID_AP: return const _RoleMods(1.04, 1.00, 0.00);
    case Role.MID_AM: return const _RoleMods(1.06, 0.96, 0.00);
    case Role.MID_WM: return const _RoleMods(1.03, 0.98, 0.015);
    case Role.MID_WB: return const _RoleMods(1.02, 1.02, 0.010);
    case Role.FWD_ST: return const _RoleMods(1.05, 1.00, 0.00);
    case Role.FWD_F9: return const _RoleMods(1.03, 1.01, 0.00);
    case Role.FWD_WG: return const _RoleMods(1.04, 0.97, 0.020);
    case Role.FWD_IW: return const _RoleMods(1.04, 1.00, 0.00);
    case Role.FWD_SS: return const _RoleMods(1.03, 1.00, 0.00);
    case Role.FWD_PC: return const _RoleMods(1.02, 0.99, 0.00);
    // GK roles impact mainly defense (gkD) or negligible field width.
    case Role.GK_STS: return const _RoleMods(1.00, 1.05, 0.00);
    case Role.GK_DSTB: return const _RoleMods(1.01, 0.97, 0.00);
    case Role.GK_CMD: return const _RoleMods(1.00, 1.02, 0.00);
    case Role.GK_SWSR: return const _RoleMods(1.00, 1.00, 0.00);
    case Role.GK_STD: return const _RoleMods(1.00, 1.00, 0.00);
  }
}

double _effectiveAttrAttack(int base, double staminaPct, Player p) {
  final role = _roleMods(p.role);
  final eff = base * (0.60 + 0.40 * staminaPct) * role.atk;
  return eff;
}

double _effectiveAttrDefense(int base, double staminaPct, Player p) {
  final role = _roleMods(p.role);
  final eff = base * (0.60 + 0.40 * staminaPct) * role.def;
  return eff;
}

double _computeMinuteFatigue(Player p, TeamConfig t) {
  // Base minute cost scaled to 90' reference (legacy base 0.10)
  final tempo = t.tactics.tempo; // 0..1
  final pressing = t.tactics.pressing; // 0..1
  // Risk proxy: approximate share of risky actions from current tactics (using bias & width heuristics)
  final riskProxy = (t.tactics.attackBias.abs() * 0.5 + tempo * 0.3 + pressing * 0.2).clamp(0.0, 1.0);
  // Split into base + variable components so ENG can reduce only variable portion.
  final baseCost = 0.08; // baseline
  double variable = EngineParams.staminaTempoDecayFactor * tempo * 0.07
      + EngineParams.staminaPressingDecayFactor * pressing * 0.06
      + EngineParams.staminaRiskProxyFactor * riskProxy * 0.05; // enlarged variable share (Tuning6)
  if (p.hasAbility('ENG')) {
    variable *= (1 - EngineParams.graphAbilityEngStaminaDecayRel); // relative reduction only on variable portion
  }
  double cost = baseCost + variable;
  // Clamp for stability
  cost = cost.clamp(0.05, 0.22);
  // ENG ability reduction (relative) applied once with milder floor.
  // (ENG reduction already applied to variable part above)
  // Role-based stamina adjustments (B2B less, WB more) small deltas
  switch (p.role) {
    case Role.MID_B2B:
      cost *= 0.95; // -5%
      break;
    case Role.MID_WB:
      cost *= 1.03; // +3%
      break;
    default:
      break;
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
  double effA(int base, double sta, Player p) => _effectiveAttrAttack(base, sta / 100.0, p);
  double effD(int base, double sta, Player p) => _effectiveAttrDefense(base, sta / 100.0, p);
  final gk = t.selected.where((p) => p.pos == Position.GK && !p.sentOff && !p.injured).toList();
  final defs = t.selected.where((p) => p.pos == Position.DEF && !p.sentOff && !p.injured).toList();
  final mids = t.selected.where((p) => p.pos == Position.MID && !p.sentOff && !p.injured).toList();
  final fwds = t.selected.where((p) => p.pos == Position.FWD && !p.sentOff && !p.injured).toList();
  double avg(List<double> xs) => xs.isEmpty ? 0.0 : xs.reduce((a, b) => a + b) / xs.length;
  final gkD = gk.isNotEmpty ? _effectiveAttrDefense(gk.first.defense, gk.first.currentStamina/100.0, gk.first) : 40.0;
  final defD = avg(defs.map((p) => effD(p.defense, p.currentStamina, p)).toList());
  final defA = avg(defs.map((p) => effA(p.attack, p.currentStamina, p)).toList());
  final midD = avg(mids.map((p) => effD(p.defense, p.currentStamina, p)).toList());
  final midA = avg(mids.map((p) => effA(p.attack, p.currentStamina, p)).toList());
  final fwdA = avg(fwds.map((p) => effA(p.attack, p.currentStamina, p)).toList());
  final fwdD = avg(fwds.map((p) => effD(p.defense, p.currentStamina, p)).toList());
  double attack = fwdA * 1.0 + midA * 0.65 + defA * 0.2;
  double defense = defD * 1.0 + midD * 0.55 + gkD * 1.2 + fwdD * 0.1;
  final bias = t.tactics.attackBias; final pressing = t.tactics.pressing; final line = t.tactics.lineHeight;
  // Width augmented by role contributions (sum capped) for players on field
  double widthAdd = 0.0;
  for (final p in t.selected) {
    widthAdd += _roleMods(p.role).width;
  }
  widthAdd = widthAdd.clamp(0.0, 0.06); // cap cumulative effect
  final width = (t.tactics.width + widthAdd).clamp(0.0, 1.0);
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
  // GK role DSTB slight team attack emphasis already via gk atk multiplier; ensure not double counted.
  return _TeamRatings(attackAdj: attack, defenseAdj: defense, gk: gk.isNotEmpty ? gk.first : null);
}

// (Graph helper functions moved to graph_public_helpers.dart for test access.)
