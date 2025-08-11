# Overview
Compact summary of Futzin: hybrid football match simulator with legacy minute engine and experimental graph micro-action engine. Goal: realistic statistical ranges with low computational cost and deterministic tuning surface.

Core pillars:
- Centralized parameters (`engine_params.dart`)
- Dual engines (legacy baseline, graph experimental)
- Action logging instrumentation for calibration
- Tiered player generation with abilities
- Future meta loop (season/economy/packs)

See `architecture.md` for structure, `engine_graph.md` for graph pipeline, and `testing_calibration.md` for validation process.
