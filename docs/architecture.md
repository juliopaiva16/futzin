# Architecture
Logical layers:
1. Domain (`lib/domain`): pure simulation & entities.
2. Presentation (`lib/presentation`): Flutter UI (pages/widgets) consuming domain via streams/state.
3. Localization (`lib/l10n` + generated): ARB driven; engine text via `MatchMessages`.
4. Docs (`docs/`): stable conceptual references.
5. Progress (`progress/`): living YAML status.

Engines:
- Legacy: minute loop → sequence (0..N passes + shot) producing `MatchEvent`.
- Graph: micro action loop (pass/dribble/long/back/hold/launch/shot) aggregated into textual events.

Parameter policy: All numeric tunables live in `engine_params.dart`; no magic numbers elsewhere.

Extensibility: Abilities & roles modify probabilities at discrete pipeline phases; new effects added via parameter hooks to preserve reproducibility.
