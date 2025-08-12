# Futzin – Copilot & LLM Guide (Slim)

Purpose: enable humans/LLMs to (a) navigate the project, (b) preserve architecture & standards, (c) operate the Markdown + YAML progress system. Compact, idempotent, diff‑friendly.

---
## 1. REPO MAP (SOURCE OF TRUTH)
Domain: `lib/domain/`
- `entities.dart` (Player/Team/Tactics/Formation, JSON, lineup rules)
- `engine_params.dart` (all tunables centralized)
- `match_engine.dart` (legacy minute → events engine)
- `graph_engine.dart` + helpers (`match_engine_sequences.dart`, `match_engine_utils.dart`, `match_engine_types.dart`) (graph micro‑actions engine)
- `messages.dart` (localized engine strings adapter)
Presentation: `lib/presentation/`
- `pages/` (shell, market, match view)
- `widgets/` (pitch, momentum chart)
Core: `lib/core/localization/` (l10n bridge)
Localization: `lib/l10n/*.arb` (en/pt) → generated `lib/l10n/generated/` (do not edit)
Tests: `test/`
Docs: `docs/` (concepts, formulas, concise guides)
Progress: `progress/` (YAML live status files)

---
## 2. DOC & YAML SYSTEM
Planned layout:
```
docs/
  overview.md
  architecture.md
  engine_legacy.md
  engine_graph.md
  engine_xg_model.md
  stamina_momentum.md
  player_generation.md
  abilities.md
  meta_loop.md
  testing_calibration.md
  glossary.md
progress/
  INDEX.yaml
  engine.yaml
  player_generation.yaml
  abilities.yaml
  meta_game.yaml
  calibration.yaml
  backlog.yaml
  risks.yaml
```
Purpose:
- Markdown = stable explanation / formulas / rationale.
- YAML = living state (phase, metrics, dates, deps).

Hierarchical Progress Schema (canonical):
All progress YAML files must follow a root‑anchored structure inspired by the former `simulation_refactor_llm_progress.md` snapshot.

Top-level keys (order fixed):
```
root:            # mandatory object
  id: slug
  title: Short Title
  status: TODO|DOING|TUNE|DONE|DEFER|DROP
  updated: YYYY-MM-DD
  owner: handle|team
  notes: | (optional multiline short lines)
    line
  phases:        # optional array (ordered incremental phases)
    - id: phase-id
      status: status
      delivered: [items]
      pending: [items]
  macro_topics:  # optional array of broader tracks
    - id: topic-id
      status: status
      goal: short phrase
      implemented: [items]
      pending: [items]
  components:    # optional domain-specific groups (abilities, tiers, etc.)
    - id: comp-id
      implemented: [items]
      pending: [items]
  metrics_current: { key: value }   # current measured metrics (floats 3dp)
  metrics_targets: { key: value|[min,max] }
  open_questions: [question_slug,...]
  next_batch_priority_order: [id1,id2,...]
  risks:          # optional embedded light risk list (or use global risks.yaml)
    - id: risk-id
      impact: 1-5
      likelihood: 1-5
      note: short
```

Rules additions:
- Every file holds exactly one `root` object.
- Lists (`phases`, `macro_topics`, `components`) keep stable ordering (append only; deprecate via status DROP not deletion).
- `metrics_current` reflects most recent batch; update atomically with `updated`.
- Cross-file references use IDs (kebab-case) listed in `progress/INDEX.yaml`.
- Prefer concise tokens; move narrative to Markdown.
- If a previous flat schema existed, migrate into `root` preserving IDs.

YAML KEY CONVENTION (fixed order for clean diffs):
```
id: unique-slug
title: Short
status: TODO|DOING|TUNE|DONE|DEFER|DROP
updated: YYYY-MM-DD
owner: handle|bot|team
deps: [ids]
metrics: { key: value }
notes: |
  Short line 1
  Short line 2
risks: [id1, id2]
next: [step1, step2]
```
Rules:
- Always bump `updated` when any other field changes.
- Never delete critical history: move it into `notes:` (short lines; no long paragraphs).
- Valid status transitions: TODO→DOING→(TUNE|DONE|DEFER). TUNE→DONE allowed. DEFER→TODO allowed.
- Numeric metrics: floats 3 decimals (2.457). Percent without % (83.2).
- IDs kebab-case; file names snake_case.

INDEX.yaml:
- Ordered list of all IDs + file path (fast LLM lookup).
- Keep alphabetical.

Backlog & Risks:
- `backlog.yaml`: not-started items (reduced schema: id,title,why,next).
- `risks.yaml`: id, desc, impact(1-5), likelihood(1-5), mitigation, owner, updated.

Update Process (PR Checklist):
1. Code changed? Sync affected metrics in YAML.
2. New concept? Add short MD doc + INDEX entry.
3. Model param changed? Update `engine_params.dart` + doc reference.
4. Run `flutter analyze` + tests.
5. Commit prefix: `[engine]`, `[graph]`, `[docs]`, `[progress]`, `[meta]`.
6. If hierarchical schema changes structure (add phase/topic), reflect in related Markdown doc referencing it.

---
## 3. ARCHITECTURE & DESIGN PRINCIPLES
Separation:
- Pure domain (no Flutter) under `lib/domain`.
- UI consumes domain via objects/streams; no simulation logic in widgets.
Parameters:
- All tunables only in `engine_params.dart` (ban magic numbers in loops).
Engines:
- Legacy kept until final phase; graph engine behind a flag (e.g. `useGraphEngine`).
Events:
- Public interface stable (`MatchEvent`) — new fields optional.
Localization:
- Engine strings through `MatchMessages`; no raw literals in logic.
Light immutability:
- Prefer const/final; encapsulate mutation.

---
## 4. DART CODING STANDARDS
Doc comments: `///` for public classes/methods/enums/critical static fields.
Inline `//` for (1) section headers, (2) brief rationale, (3) TODO(tag:short).
Formatting: `dart format .` before commit.
Lints: keep `flutter analyze` clean.
Naming:
- Classes CamelCase; methods camelCase; globals/const SCREAMING_SNAKE.
- Files: snake_case.
Numeric constants: only in `engine_params.dart` (or clearly derived locals).
Random: keep ranges modest (web friendly) & allow seed injection for tests.
Clamps: apply before exposing stats (xG, probabilities, stamina) to protect invariants.

---
## 5. ENGINE SUMMARY
Legacy: minute → (calm|attacking) → events; baseline & regression harness.
Graph: micro actions (pass, dribble, long, back, hold, launch, shot) with probabilities from positions + abilities + multi-def intercept.
Multi-feature xG: distance, angle, pressure, assist type, fallback penalty blended with legacy weight.
Forced Shot: triggers (stagnation count, post-dribble immediate) parameterized.
Stamina: minute decay + position modifiers + ENG ability.
Momentum: aggregate action contributions into bars/area (central params).

---
## 6. PLAYER & ABILITIES
Generation: correlated tiers (1..4), height, preferred foot, limited abilities.
Implemented abilities: VIS, PAS, DRB, FIN, WALL, CAT, CAP, ENG.
Pending/future effects: MRK, HDR, SPR, CLT, AER, REF, COM.
Rule: never double-apply same buff (e.g. FIN only at final pGoal stage if chosen).

---
## 7. TESTING & CALIBRATION
Always add tests for: new probabilities, multi-def intercept, ability effects.
Batch sim target ranges:
- xG total: 2.4–3.2
- Pass %: 75–88
- Dribbles: 8–25
- Intercepts: 35–65
If out of range → adjust only via `engine_params.dart` & update `engine.yaml` metrics.

---
## 8. WORKFLOW (SHORT)
Run: `flutter pub get` → `flutter run -d chrome` (or other device)
Analyze: `flutter analyze`
Format: `dart format .`
Test: `flutter test`
Perf tuning: run batch sim separately (avoid blocking UI).

---
## 9. LLM / AGENT PLAYBOOK
1. Read `progress/INDEX.yaml` for ID map.
2. Open target YAML; apply minimal diffs (preserve key order).
3. Check matching Markdown doc for needed formula/name updates.
4. Run `flutter analyze` after domain changes.
5. Update `updated:` + succinct notes (<100 chars/line).
6. Avoid duplication: YAML = state; MD = explanation.

---
## 10. COMMIT CHECKLIST
[ ] Build & analyze clean
[ ] Tests green / added
[ ] Param changes centralized
[ ] YAML state synced (updated + metrics)
[ ] INDEX.yaml updated (if new IDs)
[ ] Markdown reflects new formulas
[ ] Names & comments follow standards

---
## 11. QUICK GLOSSARY (MIN)
TUNE = functional but calibrating.
Stagnation = repeated non-progress actions causing forced shot.
Fallback Shot = low-quality shot triggered by stagnation.
Blend XG = multi-feature + legacy mix.

---
## 12. DO NOT
- Add magic numbers outside `engine_params.dart`.
- Edit generated files (l10n/generated).
- Add mandatory JSON fields without default/back-compat.
- Duplicate logic across legacy & graph (factor helpers instead).

---
## 13. YAML EXAMPLE
```
id: graph-engine-phase4
title: Additional actions softmax
status: TUNE
updated: 2025-08-11
owner: core
deps: [graph-engine-phase3]
metrics: { pass_pct: 82.1, xg_avg: 2.73 }
notes: |
  Softmax weights adjusted; intercept spike control WIP
next: [stamina-integration, ability-fin-calibration]
```

---
## 14. QUICK LOCATION SHORTCUTS
Engine params: `engine_params.dart`
Graph loop: `match_engine_sequences.dart` (sequencing) + `graph_engine.dart` (orchestration)
XG helpers: `graph_public_helpers.dart`
Player gen: `player_factory.dart`
Pitch UI: `pitch_widget.dart`
Momentum chart: `momentum_chart.dart`

---
## 15. FUTURE EVOLUTION (TRACK IN YAML)
- Set pieces, transitions, dynamic tactics, xT grid, advanced abilities, meta loop (season, economy, packs), statistical tests.

End.
