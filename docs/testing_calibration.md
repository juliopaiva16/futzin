# Calibration & Metrics Automation (LLM Guide)

Concise, dependency‑light description of the calibration pipeline so an LLM (or human) can reason, extend, or refactor without re‑opening scattered sources. Mirrors `progress/calibration.yaml` state and adds operational detail, formulas, and guardrails.

---
## 1. Snapshot (Source of Truth Reference)
Progress YAML (DO NOT edit here; update `progress/calibration.yaml`):

```yaml
root:
  id: calibration-pipeline
  title: Calibration & metrics automation
  status: TODO
  updated: 2025-08-11
  owner: core
  notes: Need automated batch script wiring & divergence scoring
  phases:
    - id: batch-runner        # seed-stable batch executor
      status: TODO
      pending: [runner-script, seed-control]
    - id: metrics-export      # structured outputs (JSONL / compressed)
      status: TODO
      pending: [jsonl-writer, compress-option]
    - id: divergence-scoring  # quantifies drift between engine versions
      status: TODO
      pending: [formula-pass, formula-xg, aggregate-weighting]
  metrics_current: { batch_runs: 0 }
  metrics_targets: { batch_runs: 10 }
  open_questions: [weighting-of-outliers, acceptable-drift-window]
  next_batch_priority_order: [define-divergence-fn, add-test-harness, baseline-export]
  risks: [tuning-complexity-spike]
```

---
## 2. Objectives
1. Deterministic batch simulation harness ( reproducible with seed ).
2. Export structured per-run + aggregated metrics for: goals, xG, pass%, dribbles (attempt & success), intercepts, stamina decay, ability impact counts.
3. Compute divergence scores vs baseline to detect unintended drift after refactors or parameter tweaks.
4. Automate updating of progress YAML metrics (`metrics_current`) atomically with date bump.

---
## 3. Pipeline Overview (Conceptual Steps)
1. Seed Setup: Accept explicit seed (int). If absent, generate & print.
2. Batch Loop: Run N simulations (parameterizable; default 200–500 for stability) using `MatchEngine` with fixed params snapshot.
3. Per Match Capture: Tally raw counters (events, goals, passes attempted/successful, dribbles attempted/successful, interceptions, stamina values at minute buckets, ability triggers).
4. Aggregation: Produce mean, stdev (Bessel), min, max for each metric. Compute derived metrics (pass_pct, dribble_success_pct, xg_per_match, goals_per_match, intercepts_per_match, stamina90_mean).
5. Divergence: Compare against stored baseline vector; output per-metric z or relative delta; weight & compress into single score.
6. Export:
   - Human console summary (for quick reading, regex-parsed by automation script).
   - JSONL (optional) each run’s aggregate snapshot.
   - Compressed archive (future) if size > threshold.
7. Update Progress: Script parses console → rewrites `metrics_current` + `updated` date inside `progress/engine.yaml` / `progress/calibration.yaml` (already implemented for engine file; extend to calibration if needed).

---
## 4. Core Metrics (Recommended Canonical Keys)
| Key | Definition | Type | Notes |
|-----|------------|------|-------|
| goals_avg | Mean goals (both teams per match) | float | Target 2.4–3.2 | 
| xg_avg | Mean expected goals (sum) | float | Should bracket goals_avg closely |
| pass_pct | Successful passes / attempted | float | Target 75–88 |
| dribble_attempts | Mean dribble attempts | float | Target 8–25 |
| dribble_success_pct | Successful dribbles / attempts | float | Stable band once tuned |
| intercepts | Mean interceptions | float | Target 35–65 |
| stamina90_mean | Mean remaining stamina at minute 90 | float | Calibrate fatigue realism |
| ability_FIN_triggers | Count FIN effect applications / match | float | Each ability tracked similarly |
| divergence_score | Composite drift indicator | float | <= drift window threshold |

Optional future: xg_calibration_mse (Shot-level), possession_share_mean, momentum_variance.

---
## 5. Divergence Scoring (Design)
Let baseline vector B and new vector V share metric set M.

Per metric m:
1. raw_delta = V[m] - B[m]
2. rel_delta = raw_delta / max(epsilon, B[m])
3. normalized = clamp(rel_delta / allowed_band[m], -1.5, 1.5)
4. weight w[m] (higher: goals, xg, pass_pct)
5. contribution = w[m] * normalized^2  (square punishes both directions; still sign reported separately)

Aggregate:
divergence_score = sqrt( Σ contribution / Σ w[m] )

Status Gates (example):
| Score | Interpretation | Action |
|-------|----------------|--------|
| 0.00–0.20 | Within noise | No change |
| 0.21–0.40 | Minor drift | Monitor, maybe adjust params |
| 0.41–0.70 | Significant | Investigate; run targeted tests |
| >0.70 | Regressed | Block merge / rollback |

Store baseline snapshot as JSON: `{ version, date, metrics: { ... } }` so upgrades are explicit.

---
## 6. Outlier Weighting (Open Question Handling)
Outlier weighting options for metrics with variance spikes (e.g., dribbles):
1. Percentile Trim: Drop top/bottom 2% before mean.
2. Winsorize: Clamp extremes to 2nd / 98th percentile.
3. Log Transform: For skewed counts (rare events).
Decision Path: Start with simple trim (cheap, explainable) → escalate if instability persists.

---
## 7. Acceptable Drift Window (Guideline)
Initial allowed relative bands (allowed_band[m]):
| Metric | Band |
|--------|------|
| goals_avg | 0.05 |
| xg_avg | 0.04 |
| pass_pct | 0.015 |
| dribble_attempts | 0.10 |
| dribble_success_pct | 0.08 |
| intercepts | 0.10 |
| stamina90_mean | 0.05 |

Tune after first 10 baseline runs (metrics_targets.batch_runs).

---
## 8. Implementation Notes & Hooks
Current script `bin/update_progress_metrics.dart` parses limited fields. Extend parsing regex list to include new metrics (stamina90, intercepts) once produced by batch runner.

Recommended file additions:
- `bin/batch_divergence.dart` (optional) → outputs JSON summary and divergence_score.
- `calibration_baseline.json` (root or under `calibration/`) storing baseline snapshot.

Determinism:
- Pass seed into `MatchEngine` & all Random usages (propagate param).
- Record seed in each run row: `{ seed, metrics... }` to reproduce anomalies.

Performance Tips:
- Parallelization: run batches sequentially for determinism measurement; optional multi‑isolate future (flagged).
- Early Abort: If partial metrics exceed drift threshold early (e.g., after 30% runs), surface preliminary warning but still complete unless flagged `--fail-fast`.

---
## 9. Risks & Mitigations
| Risk ID | Description | Mitigation |
|---------|-------------|------------|
| tuning-complexity-spike | Parameter explosion makes calibration slow | Strict single source in `engine_params.dart`; staged tuning (one cluster at a time) |
| baseline-staleness | Baseline not refreshed after intentional re-balance | Require bump of `version` field in baseline JSON + commit note |
| silent-drift | Small cumulative changes skip detection | Low bands for core metrics; nightly full batch job |
| overfitting-metrics | Tuning to pass metrics but reduces realism | Add qualitative sanity checks (distribution shapes) |

---
## 10. LLM Interaction Cheatsheet
Task → Action Mapping:
- "Update metrics after batch": Run batch script → call update script → edit YAML (bump updated) → verify analysis.
- "Add new metric": Implement tally + print + regex + YAML key; update baseline JSON & doc Section 4.
- "Investigate drift": Re-run baseline with same seed count; compute divergence; inspect largest normalized contributions.

Always: mutate only YAML (not this doc) for live state; reflect formula changes here after implementation.

---
## 11. Next Concrete Steps (From YAML Order)
1. define-divergence-fn → Implement Section 5 function + baseline JSON writer.
2. add-test-harness → Unit test ensuring divergence_score == 0 for identical vectors.
3. baseline-export → Produce initial baseline snapshot after 10 batch runs.

---
## 12. Minimal Pseudocode (Divergence Function)
```dart
double divergenceScore(Map<String,double> base, Map<String,double> current, Map<String,double> band, Map<String,double> weight){
  double sumW = 0, acc = 0;
  for (final k in weight.keys) {
    final b = base[k];
    final v = current[k];
    if (b == null || v == null) continue;
    final w = weight[k]!;
    final rel = (v - b) / (b.abs() < 1e-9 ? 1e-9 : b.abs());
    final norm = (rel / (band[k] ?? 0.05)).clamp(-1.5, 1.5);
    acc += w * norm * norm;
    sumW += w;
  }
  return sumW == 0 ? 0 : (acc / sumW).sqrt();
}
```

---
## 13. Update Discipline
When formulas, bands, or weights change:
1. Update this doc sections (5,7).
2. Commit with prefix `[calibration]` and concise rationale.
3. Regenerate baseline & increment its internal version.
4. Sync `progress/calibration.yaml` date.

---
## 14. Glossary (Focused)
| Term | Meaning |
|------|---------|
| Drift | Change in metric outside acceptable band |
| Divergence Score | Weighted RMS of normalized metric deltas |
| Baseline | Frozen metric vector used as reference |
| Band | Allowed fractional deviation before penalty grows quadratically |

---
## 15. Do / Avoid
Do: Keep metric keys stable, document every added key here first.
Do: Prefer relative deltas for scale independence.
Avoid: Mixing seed sources; adding ad‑hoc prints (breaks parser); deleting historical phases (append only).

---
End of calibration LLM guide.
# Testing & Calibration
Targets: pass%, xG total, goals, dribble attempts/success, intercepts. Ranges in progress/engine.yaml.

Process:
1. Run batch sims (script) capturing JSONL logs.
2. Extract metrics: pass success, action distribution, shot volume, xG vs goals.
3. Compare to target ranges; adjust only EngineParams.
4. Update YAML metrics + updated date.
5. Add/maintain unit tests: action selection monotonic, intercept monotonic (#defs), ability effect deltas (VIS/PAS/FIN/DRB), stamina ENG differential.

Divergence scoring (planned): weighted relative error per metric.
