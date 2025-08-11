# Testing & Calibration
Targets: pass%, xG total, goals, dribble attempts/success, intercepts. Ranges in progress/engine.yaml.

Process:
1. Run batch sims (script) capturing JSONL logs.
2. Extract metrics: pass success, action distribution, shot volume, xG vs goals.
3. Compare to target ranges; adjust only EngineParams.
4. Update YAML metrics + updated date.
5. Add/maintain unit tests: action selection monotonic, intercept monotonic (#defs), ability effect deltas (VIS/PAS/FIN/DRB), stamina ENG differential.

Divergence scoring (planned): weighted relative error per metric.
