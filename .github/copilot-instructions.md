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

## Graph Engine Refactor (2025)
A nova engine baseada em grafo será desenvolvida incrementalmente em paralelo à atual (`match_engine.dart`). Consulte:
- Proposta: `docs/simulation_refactor_proposal.md`
- Progresso: `docs/simulation_refactor_progress.md`
- Habilidades & Roles: `docs/abilities_and_roles.md`

### Objetivo resumido
Migrar de sequência sintética de eventos para micro-decisions dirigidas por um grafo (jogadores = nós, passes = arestas), preservando interface de eventos (`MatchEvent`).

### Fases (marcar no arquivo de progresso ao concluir)
1. Role enum + coordenadas de jogadores (nenhuma mudança lógica externa).
2. Micro motor simples (passes curtos + chute) opcional via flag experimental.
3. Arestas ponderadas + interceptação multi-defensor.
4. Ações adicionais (drible, passe longo, recuar, manter, lançamento) + softmax.
5. Habilidades integradas (passes, drible, finalização, defesa).
6. Novo modelo de stamina & recalibração ratings.
7. Tuning momentum/xG para manter ranges.
8. Flag e UI toggle (Experimental Graph Engine).
9. Remoção engine antiga após validação.

### Orientações de Implementação
- Criar novo módulo `lib/domain/graph_engine.dart` (não modificar engine antiga até fase 5+ estar estável).
- Introduzir `Role` e campo `role` no `Player` com backward compat no JSON (atribuir default baseado em macro posição se ausente).
- Centralizar parâmetros em classe `EngineParams` (um arquivo dedicado ex: `lib/domain/engine_params.dart`).
- Cada alteração estrutural deve atualizar `docs/simulation_refactor_progress.md` (status + data).
- Manter clamps estritos (xg, pGoal, stamina) conforme proposta para evitar regressões estatísticas.
- Habilidades (abilities) existentes + novas: mapear códigos → efeitos em fases (arestas, scoring, resolução). Evitar aplicar o mesmo buff duas vezes (ex: FIN só em pGoal pós-save, não em xg_raw se escolhido assim no progresso).
- Sempre rodar `flutter analyze` e adicionar testes unitários para: seleção de ação monotônica, intercept multi-defensor, efeitos de habilidades (VIS reduz intercept ~10% relativo, FIN aumenta pGoal dentro do cap, ENG stamina retention).
- Evitar quedas de performance: batch micro-ticks em eventos logados; não recalcular todas as arestas a cada tick se não houve movimento relevante (usar throttle ou dirty flags de posição).
- UI: manter compat com `MatchEvent`; novos campos (ex: coordenadas chute) podem ser adicionados futuramente mas devem ficar opcionais.

### Testes & Métricas
Durante tuning, produzir batch de simulações (≥200 jogos) para comparar: xG total (meta 2.4–3.2), % passe (75–88%), dribles (8–25), intercepts (35–65). Ajustar parâmetros em bloco único (EngineParams) para facilitar iteração.

### Segurança / Retrocompat
- Guardar versão de estado (ex: `futsim_state_version: 2`). Se ausente, assumir engine antiga e atribuir roles padrão.
- Não quebrar persistência de `futsim_state_v1` até migração final; apenas estender.

### Checklist rápido por PR
1. Atualizou progresso? (docs/simulation_refactor_progress.md)
2. Adicionou/ajustou testes? (`test/`)
3. Rodou `flutter analyze` sem warnings novos?
4. Respeitou clamps e não duplicou buffs de habilidades?
5. Código isolado por feature flag se fase < 8?

## MCP Tooling & Agent Behavior (Meta)
Estas orientações complementam o fluxo existente para garantir uso consistente das ferramentas MCP disponíveis.

### Princípios
- Sempre que uma resposta exigir: (a) raciocínio multi‑etapas não trivial, (b) planejamento de implementação, (c) decomposição de requisitos ambíguos → invocar o mecanismo de pensamento sequencial (`mcp_sequentialthinking`).
- Antes de assumir contexto não confirmado do repositório, preferir busca/leituras: usar buscas semânticas ou greps (ferramentas padrão) e, para conhecimento externo, extensões MCP relevantes.
- Após decisões de arquitetura, criação/alteração de entidades, parâmetros, ou conclusões de análises significativas → persistir resumo na memória usando os endpoints `mcp_memory_*` (create_entities / add_observations / create_relations). Garantir que observações sejam curtas, factuais e versionadas se necessário.

### Uso das Ferramentas MCP
- Context / Documentação Externa: se precisar de documentação de libs, resolver ID com `mcp_context7_resolve-library-id` e depois `mcp_context7_get-library-docs` focando tópico específico.
- Repositórios Externos (análise de design): usar deepwiki (`mcp_deepwiki_*`) para perguntas estruturadas em vez de copiar código.
- Navegação / Interação Web (prototipagem, verificação visual): usar playwright (`mcp_playwright_browser_*`). Encerrar abas/sessões ao final para evitar resíduos.
- Memória de Projeto: cada feature concluída ou decisão chave → `mcp_memory_add_observations`; relações entre conceitos (ex: PlayerNode -> Role influences) → `mcp_memory_create_relations`.
- Revisões: atualizar ou remover observações obsoletas com `mcp_memory_delete_observations` / `mcp_memory_delete_entities` para manter memória limpa.

### Sequência Recomendada de Resposta
1. (Opcional) Pensamento inicial curto → chamar sequential thinking para expandir plano.
2. Reunir contexto faltante (buscas ou docs) antes de editar.
3. Aplicar mudanças mínimas (atomic commits) conforme instruções principais do arquivo.
4. Atualizar arquivos de progresso / docs quando impactados.
5. Persistir snapshot conciso das decisões na memória MCP.
6. Responder ao usuário de forma curta, confirmando próximos passos.

### Boas Práticas
- Não duplicar persistência: só adicionar observações novas ou mutações relevantes.
- Evitar armazenar trechos extensos de código na memória; preferir descrições.
- Marcar cada observação com contexto temporal (ex: `2025-08-09: Phase1 PlayerNode added`).
- Reavaliar necessidade de novo bloco sequential thinking antes de grandes refactors subsequentes.

### Limites
- Se uma ferramenta não retornar dados esperados, relatar e sugerir alternativa antes de prosseguir.
- Manter aderência às políticas (sem conteúdo sensível / licenças infringidas) mesmo durante coleta via MCP.
