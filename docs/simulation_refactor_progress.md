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
| 3 | Arestas ponderadas + intercept multi-defensor | Peso aresta, pressão, intercept calc | TODO | - | - |
| 4 | Ações adicionais (PassLongo, Drible, Recuar, Manter, Lançamento) | Scoring tabela, softmax decisão | TODO | - | - |
| 5 | Habilidades (passes + drible + finalização + defesa) | Aplicar mapa de efeitos por fase | TODO | - | - |
| 6 | Stamina nova + recalibração ratings | Decay tick, attrEff, testes ENG | TODO | - | - |
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
- [ ] Switch condicional (flag experimental) para usar graph path vs _buildAttackSequence. // parcial (já alterna sequência)
- [ ] Test unit: action selection monotonicidade (fase 4).
- [ ] Implementar intercept multi-defensor (fase 3) com P_intercept.
- [ ] Drible resolução (fase 4).
- [ ] Long pass (fase 4) + penalização distância.
- [ ] Habilidades passes (VIS, PAS) → peso aresta / probSucesso.
- [ ] Habilidades finalização (FIN, HDR, CLT) → pós pGoal.
- [ ] Habilidades defensivas (WALL, MRK, AER, REF, CAT, COM) → pSave / pGoal.
- [ ] Habilidades stamina (ENG, B2B, SPR, SWS) → decay.
- [ ] Tuning script batch sim (500 jogos) comparar baseline.
- [ ] Atualizar momentum cálculo para micro-ticks (agregado).
- [ ] Documentar parâmetros ajustados no final.

## 3. Métricas de Validação (Capturar por Fase)
| Métrica | Alvo | Baseline Atual | Medido (Último) | Notas |
|---------|------|----------------|-----------------|-------|
| xG total jogo | 2.4–3.2 | Legacy 0.69 (xG sum) | Graph 0.51 | Aproximando alvo inferior |
| Gols/jogo | 2.4–3.2 | Legacy 2.83 | Graph 2.30 | Próximo range alvo |
| Chutes/jogo | 18–30 | Legacy 13.0 | Graph 11.6 | Lento aumento |
| Passes/jogo (logados) | 250–400 | Legacy ~27.7 events | Graph 36.5 events | - |
| % Sucesso passe | 75–88% | Legacy 74.2% | Graph 74.1% | Quase alvo mínimo |
| Dribles tentados | 8–25 | 0 | 0 | - |
| % Sucesso drible | 40–60% | - | - | - |
| Intercepts/jogo | 35–65 | 9.6 | 12.7 | Baixo vs macro alvo (dif. escala) |
| Stamina média 90' | 30–55 | ? | ? | Pend. |

(Preencher baseline via script antes da fase 3.)

## 4. Decisões Tomadas
| Data | Decisão | Motivo |
|------|---------|--------|
| - | - | - |

## 5. Pendências / Open Questions
- Ajustar limites de distância (passLong vs lançamento) conforme testes visuais.
- Definir se FIN modifica xg_raw ou pGoal (decisão final: pGoal apenas?).
- Representar bloqueio (BLK) como texto + redução pGoal ou apenas flavor?

## 6. Riscos Atuais
| Risco | Prob | Impacto | Mitigação |
|-------|------|---------|-----------|
| Cresc. complexidade tuning antes de métricas | M | H | Script batch cedo (fase 3) |
| Latência web micro-ticks | M | M | Batch 4–6 ticks/event |
| UI sobrecarregada com eventos | L | M | Agrupamento textual |

## 7. Próxima Ação Imediata
(Atualizar sempre que concluir algo.)
- Criar script baseline (≥200 jogos) coletando xG, chutes, passes (contar eventos pass), intercepts, para comparar antes de multi-defensor (fase 3).

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

## 9. Referências Cruzadas
- Proposta completa: `docs/simulation_refactor_proposal.md`
- Habilidades & Roles: `docs/abilities_and_roles.md`

---
(Manter este arquivo enxuto; detalhes conceituais permanecem na proposta.)
