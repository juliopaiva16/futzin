# Copilot Instructions for Futzin

This repo is a Flutter (Dart) football match simulator. The core loop simulates minutes, emits structured events, and renders a pitch + momentum chart. Use these notes to be productive quickly.

## Architecture map
- Domain (lib/domain)
  - entities.dart: Player, TeamConfig, Tactics, Formation. Lineup rules (exact 1 GK, counts per formation), autosub state, JSON (de)serialization and persistence helpers.
  - match_engine.dart: Simulation engine. Emits `MatchEvent` via a broadcast stream while a `Timer` advances minutes. Contains event types (info/shot/goal/card/injury), possession accumulation, xG, speed control (`setSpeed`).
  - messages.dart: `MatchMessages` abstraction for localized engine strings.
- Presentation (lib/presentation)
  - pages/home_page.dart: UI shell. Generates squads, persists state with shared_preferences, wires engine -> UI, speed selector, share log.
  - widgets/pitch_widget.dart: CustomPainter drawing players (A left→right, B right→left). Honors `Tactics.lineHeight` and `Tactics.width`. Supports midfield split rows via `Formation.midRows` (e.g., 4-2-3-1 = [2,3]).
  - widgets/momentum_chart.dart: CustomPainter aggregating per-minute momentum and markers (goal/shot/card/injury). Uses smoothed weights and draws filled blue/red areas.
- Core (lib/core)
  - localization/app_localizations.dart: re-export of generated l10n (EN/PT).
- l10n
  - l10n.yaml config. ARB files under lib/l10n. Generated output in lib/l10n/generated with `synthetic-package: false`.

## Engine details you’ll need
- Minute loop: calm vs attacking minute determined by `tempo`-weighted probability. Calm → 50/50 possession. Attacking → choose side based on `attackAdj/defenseAdj` comparison.
- Ratings:
  - Attack ≈ FWD ATT (1.0) + MID ATT (0.65) + DEF ATT (0.2), adjusted by bias/width/line.
  - Defense ≈ DEF DEF (1.0) + MID DEF (0.55) + GK DEF (1.2) + FWD DEF (0.1), adjusted by bias/width/line and pressing (+6.0).
  - Stamina effect: eff = base × (0.60 + 0.40 × stamina/100). Fatigue per minute increases with `tempo` and `pressing`.
- Events carry visualization metadata: `MatchEvent.kind`, `side` (+1 A / −1 B / 0 neutral), `shotXg`, `cardColor`. Cards are attributed to the defending side for momentum markers.
- Possession heuristic: calm minute ~30s each; attacking minute ~20–60s, ~65% to attacker.
- Speed control: `_baseTickMs = 450`, `setSpeed(0.25..10x)` resets the timer.

## UI patterns
- Momentum chart: denser sampling per minute (4 samples), stronger vertical scale, markers jittered/staggered to reduce overlap. Use `withValues(alpha: ...)` (not deprecated `.withOpacity`). Ensure all math produces `double` (cast/clamp where needed) to avoid num→double analyzer errors.
- Pitch layout: compute X factors per line; use `lineHeight` to shift DEF/FWD and `width` to spread vertically. Midfield split via `formation.midRows`.
- Home page: keep AppBar compact (icon buttons) to avoid RenderFlex overflow. Share via `SharePlus.instance.share(ShareParams(...))`.

## Workflows
- Run: `flutter pub get`, then `flutter run -d chrome|android|ios|macos|linux|windows`.
- Analyze: `flutter analyze` (repo kept clean). Format with `dart format .`.
- Tests: `flutter test` (add unit tests for engine probabilities/momentum if you change math).
- i18n: Update ARB in `lib/l10n/*.arb`. `l10n.yaml` outputs to `lib/l10n/generated`. Access via `AppLocalizations.of(context)` and provide `_FlutterMatchMessages` to the engine.
- Persistence: lineups saved to SharedPreferences key `futsim_state_v1` as JSON (see HomePage `_saveState()`).

## Conventions & gotchas
- Domain enum names are uppercase (GK/DEF/MID/FWD); analyzer ignore is documented in entities.dart.
- Do not modify generated files under `lib/l10n/generated`.
- Avoid using `withOpacity()` (deprecated in this SDK); prefer `withValues(alpha: ...)`.
- For random usage on web, avoid large `nextInt` ranges (prior fix: use small bounds like 1e6 for IDs).
- When editing painters, cast/clamp numeric values to double to satisfy `Offset`/Canvas APIs.

## Extension points
- Tuning probabilities in `match_engine.dart` (eventChance, pass/intercept/foul odds, xG, GK save factor).
- Add formations by extending `Formation.formations` (optionally set `midRows`).
- Add auto-subs logic in `TeamConfig`/engine; expand event kinds; add extra time/penalties.

## File beacons
- Engine: `lib/domain/match_engine.dart` (minute loop, events, possession, speed)
- Entities: `lib/domain/entities.dart` (formation, tactics, team)
- UI wiring: `lib/presentation/pages/home_page.dart`
- Painters: `lib/presentation/widgets/{pitch_widget,momentum_chart}.dart`

Keep changes small and run `flutter analyze` after edits. If adding UI text, update both ARB files.
