# Monitoramento Refactor Engine (Graph Model)

Este arquivo acompanha a execução da proposta em `simulation_refactor_proposal.md`.
Atualize em cada commit relacionado. Mantenha histórico sucinto e datado (UTC).

## 0. Convenções
- Status tags: TODO / DOING / DONE / HOLD / REVIEW / TUNE
- Checklist marcado somente após testes mínimos passarem.
- Métricas alvo ver seção 16 da proposta.

## 1. Fases & Checklist
| Fase | Descrição | Itens Principais | Status | Data Início | Data Fim |
|------|-----------|------------------|--------|-------------|----------|
| 1 | Infra posições & Role enum (sem mudar lógica) | Role enum, coord alloc, serialização | DONE | 2025-08-09 | 2025-08-09 |
| 2 | Micro motor PassCurto + Chute simples | PlayerNode adapter, edge builder básico, substitui _buildAttackSequence opcional | DONE | 2025-08-09 | 2025-08-09 |
| 3 | Arestas ponderadas + intercept multi-defensor | Peso aresta, pressão, intercept calc | DONE | 2025-08-09 | 2025-08-09 |
| 4 | Ações adicionais (PassLongo, Drible, Recuar, Manter, Lançamento) | Scoring tabela, softmax decisão | TUNE | 2025-08-09 | - |
| 5 | Habilidades (passes + drible + finalização + defesa) | Aplicar mapa de efeitos por fase | TUNE | 2025-08-09 | - |
| 6 | Stamina nova + recalibração ratings | Decay tick, attrEff, testes ENG | DOING | 2025-08-09 | - |
| 7 | Momentum/xG tuning | Ajustar ranges, comparar baseline | TODO | - | - |
| 8 | Flag modo experimental + UI toggles | Persistência flag, fallback engine antiga | DONE | 2025-08-09 | 2025-08-09 |
| 9 | Limpeza e remoção engine antiga | Deprecar código legado | TODO | - | - |

## 2. Tarefas Detalhadas (Backlog)
- [x] Criar enum Role e map de multiplicadores. // multiplicadores virão depois; enum criado
- [x] Adicionar campo `role` em Player (JSON backward compat).
- [x] Função para gerar coordenadas iniciais a partir de formation + tactics.
- [x] Estrutura PlayerNode + adapter from Player. // implementado fase 1
- [x] EngineGraph stub lado a lado (`graph_engine.dart`).
- [x] Parâmetros centrais (EngineParams) + arquivo único.
- [x] Integração inicial layout na HomePage (pré-kickoff).
- [x] Implementar flag experimental persistida (UI toggle, ainda sem lógica de sim).
- [x] Edge builder curto (dist, weight trivial=1/dist) Fase 2.
- [x] Seleção de alvo pass usando RNG proporcional.
- [x] Chute simples (reuse fórmula antiga xg) integrando posição (distGol).
- [x] Switch condicional (flag experimental) para usar graph path vs _buildAttackSequence.
- [x] Implementar intercept multi-defensor (fase 3) com P_intercept (modelo complementar multiplicativo v2).
- [x] Arestas ponderadas: penalização de congestion (graphEdgeCongestion*).
- [x] Drible resolução básica (probabilidade + avanço pequeno + falha → perda).
- [x] Long pass + penalização por distância + blend intercept.
- [x] Ações adicionais (back, hold, launch) + pesos e caps por sequência.
- [x] Boost adaptativo pós ação arriscada (graphAdaptiveShortBoost).
- [x] Habilidades passes (VIS, PAS) aplicadas em intercept & sucesso.
- [x] Habilidades drible (DRB) aplicadas (peso + sucesso).
- [x] Habilidades finalização (FIN) aplicadas pGoal pós cálculo (sem duplicar xG).
- [x] Habilidades defensivas parciais (WALL intercept rel, CAT save/pGoal + rating parcial, CAP team adj).
- [x] Habilidades stamina (ENG) reduzindo decay básico (fase parcial - restante modelo stamina fase 6).
- [ ] Outras habilidades planeadas (MRK, AER, REF, COM, HDR, CLT, B2B, SPR, SWS) – não implementadas.
- [x] Script batch expandido (métricas detalhadas: tipos de passe, drible, launch, habilidades).
- [ ] Test unit: action selection monotonicidade.
- [ ] Test unit: intercept multi-defensor monotônico (#defs ↑ → P_intercept ↑).
- [ ] Test unit: efeitos VIS/PAS/FIN/DRB estatisticamente (> threshold relativo) em cenários fixos.
- [ ] Atualizar momentum cálculo para micro-ticks (agregado).
- [ ] Documentar parâmetros ajustados no final.

## 3. Métricas de Validação (Capturar por Fase)
| Métrica | Alvo | Baseline Atual | Medido (Último) | Notas |
|---------|------|----------------|-----------------|-------|
| xG total jogo | 2.4–3.2 | Legacy 0.69 (xG sum) | Graph 0.53 | Abaixo escala alvo (futuro ajuste escalar) |
| Gols/jogo | 2.4–3.2 | Legacy 2.83 | Graph 2.30–2.46 | Dentro intervalo inferior |
| Chutes/jogo | 18–30 | Legacy 13.0 | Graph 11.7–11.8 | Precisa ↑ (ações geram menos chutes) |
| Passes/jogo (logados) | 250–400 | Legacy ~27.7 events | Graph 30–36 events | Escala eventos ≠ passes reais (representação compacta) |
| % Sucesso passe (ALL) | 75–88% | Legacy 74.2% | Graph 71.9% | Ainda abaixo alvo, tuning pendente |
| Dribles tentados | 8–25 | 0 | ~3.8 | Abaixo alvo (weights/caps limitando) |
| % Sucesso drible | 40–60% | - | ~50.5% | Dentro alvo para amostra pequena |
| Intercepts/jogo | 35–65 | 9.6 | 12.8 | Escala diferente; talvez multiplicar eventos micro no futuro |
| Stamina média 90' | 30–55 | ? | ? | Nova stamina (fase 6) pendente |
| ENG retenção stamina | +10–20pp vs controle | - | Parcial (redução decay implementada) | Medir após batch c/ abilities |

(Últimas medições: batches de 50–200 jogos em modo graph.)

## 4. Decisões Tomadas
| Data | Decisão | Motivo |
|------|---------|--------|
| 2025-08-09 | Multi-def intercept usa modelo complementar (1-Π(1-p_i)) com caps v2 | Reduz explosão de interceptações iniciais |
| 2025-08-09 | Long pass intercept mistura 70% modelo longo + 30% base | Controlar risco elevado pós ações fase 4 |
| 2025-08-09 | Caps por sequência (1 drible, 1 long) | Reduz cascata de ações arriscadas |
| 2025-08-09 | FIN aplicado apenas em pGoal (não em xg_raw) | Evitar dupla contagem |
| 2025-08-09 | BOOST adaptativo após ação arriscada | Incentivar consolidação (short pass) |
| 2025-08-09 | Métricas batch estendidas com habilidades | Visibilidade de impacto tuning futuro |

## 5. Pendências / Open Questions
- Escala de métricas (eventos vs passes reais) – decidir se expandir log para micro contagem.
- Aumentar frequência de dribles sem reduzir sucesso de passe global.
- Aplicar ENG na fadiga e reequilibrar intercept chances pós stamina model.
- Introduzir habilidades defensivas restantes (MRK/AER/REF/COM) e cabeceio (HDR) em pipeline de chute.
- Reavaliar alvo de intercepts após definir mapping evento->passes reais.

## 6. Riscos Atuais
| Risco | Prob | Impacto | Mitigação |
|-------|------|---------|-----------|
| Cresc. complexidade tuning antes de métricas | M | H | Script batch detalhado + testes unit próximos |
| Latência web micro-ticks | M | M | Manter agregação textual; considerar throttling |
| Sub-representação de dribles | M | M | Ajustar wDribble dinâmica (ex: penalizar repetição só após falha) |
| Escala xG baixa | M | M | Recalibrar coeficientes fase 7 |

## 7. Próxima Ação Imediata
- Adicionar testes unit básicos (VIS reduz intercept ~10%; FIN aumenta pGoal relativo) e iniciar aplicação ENG na fadiga (fase 6 preparatória).

## 8. Log de Progresso
| Data | Fase | Ação | Status |
|------|------|------|--------|
| 2025-08-09 | 1 | Fase 1 iniciada (marcar DOING, preparar enum Role) | DONE |
| 2025-08-09 | 1 | Enum Role criado e campo role em Player incluído (serialização) | DONE |
| 2025-08-09 | 1 | EngineParams criado + graph_engine.dart stub + layout coords | DONE |
| 2025-08-09 | 1 | Layout integrado na HomePage (pré-kickoff) | DONE |
| 2025-08-09 | 1 | PlayerNode adapter adicionado (não usado ainda) | DONE |
| 2025-08-09 | 8 | Flag experimental persistida + toggle UI | DONE |
| 2025-08-09 | 2 | Edge builder curto + seleção de passes + chute simples (graph seq) | DONE |
| 2025-08-09 | Base | Baseline 200j legacy & graph coletado | DONE |
| 2025-08-09 | 3 | Multi-def intercept v2 tuning (radius 0.15→0.13, perDef 0.030→0.022, window 0.08–0.92→0.10–0.90) métricas 200j | TUNE |
| 2025-08-09 | 3 | Multi-def intercept v2 tuning ajuste 2 (base intercept 0.10→0.095, radius 0.13→0.12, perDef 0.022→0.020) | TUNE |
| 2025-08-09 | 3 | Ajuste passMax 3→4 e interceptDistFactor 0.15→0.13 (batch 200j) | TUNE |
| 2025-08-09 | 3 | Tuning step1: graphInterceptBase 0.095→0.090 (batch 200j) | TUNE |
| 2025-08-09 | 3 | Tuning step2: perDefBaseV2 0.020→0.019 (batch 200j) | TUNE |
| 2025-08-09 | 3 | Tuning step3: interceptDefenseFactor 0.18→0.17 (batch 200j) | TUNE |
| 2025-08-09 | 3 | Implementado edge weighting por congestion (graphEdgeCongestion*) | DONE |
| 2025-08-09 | 4 | Introdução ações (drible,long,back,hold,launch) - regressão métricas (passes↓, sucesso↓) | TUNE |
| 2025-08-09 | 4 | Recalibração inicial ações (redução pesos long/launch, blend intercept long) | TUNE |
| 2025-08-09 | 4 | Recalibração 2 (short weight + long model soften) resultados 200j | TUNE |
| 2025-08-09 | 4 | Caps por sequência (1 drible / 1 long) + ajuste pesos adicionais | TUNE |
| 2025-08-09 | 4 | Adaptive short boost pós ação arriscada | TUNE |
| 2025-08-09 | 5 | Integração habilidades (VIS, PAS, DRB, FIN, WALL, CAT, CAP) em intercept/drible/pGoal/ratings | TUNE |
| 2025-08-09 | 6 | ENG aplicado na fadiga (redução decay) | DOING |
| 2025-08-09 | Batch | Script batch expandido (tipos passe, drible, launch) | DONE |
| 2025-08-09 | Batch | Script batch ampliado p/ métricas de habilidades | DONE |

## 9. Referências Cruzadas
- Proposta completa: `docs/simulation_refactor_proposal.md`
- Habilidades & Roles: `docs/abilities_and_roles.md`

---
(Manter este arquivo enxuto; detalhes conceituais permanecem na proposta.)

## Próxima Ação Imediata
- Atribuir habilidades aleatórias controladas no batch para gerar métricas e validar ENG retenção, VIS intercept ↓, FIN pGoal ↑.
