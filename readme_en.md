# Futzin – Developer README (EN)

A Flutter-based football (soccer) match simulator featuring formations, tactics, xG, momentum and localized messages.

- Tech: Flutter (Material 3), Dart. Targets: Android, iOS, Web, Desktop.
- i18n: ARB + gen-l10n (EN/PT). Non-synthetic output to `lib/l10n/generated`.
- Architecture: simple layered structure (domain, presentation, core).

## Project structure
```
lib/
  app/                   # (if added) App bootstrap
  core/
    localization/        # AppLocalizations re-export
  domain/
    entities.dart        # Player, TeamConfig, Tactics, Formation
    match_engine.dart    # Simulation engine, events stream
    messages.dart        # MatchMessages abstraction (localized text)
  presentation/
    pages/home_page.dart
    widgets/
      pitch_widget.dart  # Pitch painter
      momentum_chart.dart# Momentum chart painter
      team_config_widget.dart
l10n/
  app_en.arb, app_pt.arb
  l10n.yaml              # gen-l10n config
```

## Key concepts
- MatchEngine: produces a stream of `MatchEvent` per simulated minute.
  - Speed control with `setSpeed(multiplier)`; default base tick ~450ms.
  - Events carry: minute, text, score A/B, xG A/B, and visualization metadata (`kind`, `side`, `shotXg`, `cardColor`).
  - Possession heuristic: calm minute ~30s each; attacking minute ~20–60s with ~65% to attacker.
- Team ratings:
  - Attack ≈ FWD ATT (1.0) + MID ATT (0.65) + DEF ATT (0.2), adjusted by tactics.
  - Defense ≈ DEF DEF (1.0) + MID DEF (0.55) + GK DEF (1.2) + FWD DEF (0.1), adjusted by tactics and pressing.
  - Stamina reduces effectiveness linearly (60–100%). Fatigue depends on tempo/pressing.
- MomentumChart: smoothed per-minute weights, filled blue/red areas, markers: goal, shot, card, injury.
- PitchWidget: left→right vs right→left layouts, supports split midfield rows (e.g., 4-2-3-1 = [2,3]).

## Running
- flutter pub get
- flutter run -d chrome|android|ios|macos|linux|windows
- flutter analyze; flutter test

## Localization
- Config: `l10n.yaml` sets `synthetic-package: false`, `output-dir: lib/l10n/generated`.
- Access via `AppLocalizations.of(context)` and `_FlutterMatchMessages` adapter.

## Dependencies
- share_plus (SharePlus.instance.share(ShareParams(...)))
- shared_preferences
- flutter_localizations

## Coding notes
- Follow analyzer; enums and helpers kept concise. Some ignores exist for domain enums (GK/DEF/MID/FWD).
- Engine is deterministic only with a fixed seed (optional parameter).
- UI uses CustomPainter for pitch and momentum for low overhead.

## Extensibility ideas
- Add extra formations and tactical sliders (e.g., compactness, buildup style).
- Add substitutions AI (auto) and fatigue-based prompts.
- Add extra time/penalties; tournament/bracket mode.
- Persist last speed; richer export formats.

## Contributing
- PRs welcome. Keep code formatted with `dart format .`.
- Tests: add unit tests for engine probabilities and momentum aggregation.

## License
- MIT (suggested) – add a LICENSE file if distributing.
