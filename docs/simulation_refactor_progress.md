# (DEPRECATED) Monitoramento Refactor Engine (Graph Model)

Substituído pelos arquivos YAML em `progress/` (ver `progress/INDEX.yaml`).
Não atualizar este arquivo; manter somente como referência histórica compacta.

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
| 7 | Momentum/xG tuning | Ajustar ranges, comparar baseline | DOING | 2025-08-11 | - |
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
- [x] Script batch expandido (métricas detalhadas: tipos de passe, drible, launch, habilidades).

- Ordem recomendada para próximos itens
1. [ ] (6.3) Centralizar cálculo attr efetivo (`effectiveAttr`) 
2. [ ] (6.6) Métricas avançadas de stamina (Q1..Q4, ENG vs non-ENG) no batch
3. [ ] (6.4) Recalibrar peso stamina (0.40→0.35–0.38 se necessário) após métricas
4. [ ] (6.5) Retune % passe (ajustar intercept/pesos short) visando 75–88%
5. [ ] Outras habilidades (MRK, AER, REF, COM, HDR, CLT, B2B, SPR, SWS)
6. [ ] Atualizar momentum cálculo para micro-ticks (agregado)
7. [ ] Documentar parâmetros ajustados finais (fase 6 baseline)
8. [ ] Test unit: action selection monotonicidade
9. [ ] Test unit: intercept multi-defensor monotônico (#defs ↑ → P_intercept ↑)
10. [ ] Test unit: efeitos VIS/PAS/FIN/DRB (redução/elevação relativa)

### TODO (Novas sugestões próximos passos - Tuning Global)
11. [ ] Implementar fallback de chute ao atingir passMax sem early shot (garantir tentativa de finalização)
12. [ ] Adicionar pequena chance de chute pós-drible bem-sucedido mesmo fora da zona ideal (aumentar volume de chutes)
13. [ ] Ajustar early shot: dist 0.30 e prob moderada + manter dampening forte de pGoal início (equilibrar volume vs conversão)
14. [ ] Pass success uplift: interceptBase 0.064→0.062 + multi-cap 0.28→0.26 + buffs leves VIS/PAS (VIS rel 0.10→0.12, PAS short rel 0.05→0.06)
15. [ ] xG alignment: aumentar graphXgBase 0.055→0.065 e reduzir graphXgBlendAttack 0.55→0.48 (mais peso posição) antes de novo ajuste pGoal
16. [ ] Converter ENG métrica: redefinir cálculo decay (base 0.08→0.06, ampliar variável) para atingir redução relativa ~15% em vez de ~50%
17. [ ] Aplicar efeitos mínimos habilidades novas:
	- MRK: interceptChance *= (1 + rel)
	- HDR: bônus xG se dxGoal < limiar cabeceio (ou se altura simulada > threshold futuramente)
	- AER/REF/COM: componentes distintos na fórmula de pSave (separar reflexo vs posicionamento)
	- CLT: boost pGoal relativo >=75' (clamp para não inflar demais conversão)
	- SPR: aumentar componente paceDiff no drible
18. [ ] Separar pGoal pipeline em estágios (posQual → shotQuality → finishModifiers) para permitir injeção clara de habilidades futuras
19. [ ] Adicionar métricas batch: distribuição passes por comprimento, % chutes após n passes, conversão early vs late shot
20. [ ] Test unit novos: MRK aumenta intercept, HDR aumenta xG de cabeceio artificial, SPR aumenta pSucesso drible pace-dominante
21. [ ] Normalizar logging para permitir contagem realista de passes (opcional micro-eventos) antes do tuning final de % sucesso
22. [ ] Criar flag de relatório resumido vs detalhado no batch script (--summary)
23. [ ] Inserir clamp consistente de prob intermediárias (antes e depois de cada mod) para facilitar debug estatístico
24. [ ] Documentar diagrama pipeline de decisão (pass/drible/long/hold/launch → shot) com pontos de intervenção de habilidades
25. [ ] Preparar script de comparação legacy vs graph (mesmos seeds) exportando CSV para análise externa

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
- Momentum agora parametrizado (EngineParams.momentum*); chart consome momentumDelta quando disponível. Próximo: testes simples para magnitudes e ajuste fino dos coeficientes.

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
| 2025-08-09 | 6 | Centralizado effectiveAttr + role multipliers básicos + testes intercept/FIN | DOING |
| 2025-08-09 | 6 | Tuning: closeChance↓, intercept↓, dribble weight↑, ENG nerf, early shot trigger | TUNE |
| 2025-08-09 | 6 | Tuning2: xG coeff↑, earlyShot prob↑ dist↓, intercept dist/press↓, DRB nerf, stamina floor ENG | TUNE |
| 2025-08-10 | 6 | Corrective: soften intercept further, raise xG coeff, earlyShot prob↑ (will dial back next), ENG decay clamp adjust | TUNE |
| 2025-08-10 | 6 | Tuning3: reduce earlyShot prob/dist, lower pGoalMax & FIN boost, soften intercept more, dribble weight↑ success↓, xG coeff slight down | TUNE |
| 2025-08-10 | 6 | Tuning4: extend pass chains (passMax 5), soften intercept base, raise xG base/coeff, lower earlyShot prob, ENG variable-only decay | TUNE |
| 2025-08-10 | 6 | Tuning5: reduce conversion (pGoal base 0.88, stronger GK), raise earlyShotProb 0.34, soften intercept base & multi-cap, moderate xG coeff | TUNE |
| 2025-08-10 | 6 | Tuning6: shot volume push (earlyShotProb 0.40), conversion curb (pGoal base 0.85, GK factor↑), intercept base 0.064, multi-cap 0.28, ENG variable scaling expanded + rel 0.05 | TUNE |
| 2025-08-10 | 5 | Scaffolding novas habilidades (MRK, AER, REF, COM, HDR, CLT, SPR) placeholders EngineParams + entities doc | DONE |
| 2025-08-11 | 6 | Public fatigue helper + tests (FIN pGoal, multi-def intercept monotonic, VIS intercept reduction, ENG stamina) | DOING |
| 2025-08-11 | 6 | Implementados: fallback forced shot, post-dribble shot chance, intercept/xG param adjustments (itens backlog 11-15 parciais) | TUNE |
| 2025-08-11 | MT2 | Player generation: adicionados heightCm, preferredFoot, tier (parcial) | DOING |
| 2025-08-11 | MT2 | PlayerFactory com atributos correlacionados + testes | DOING |
| 2025-08-11 | MT3 | Dynamic shot volume controls (post-dribble prob + forced shot logic) | DOING |
| 2025-08-11 | MT4 | Pass success tuning: tempo & width intercept mitigations + helper/test | DOING |
| 2025-08-11 | MT4 | Alternate intercept blend model + pass outcome logging | DOING |
| 2025-08-11 | MT5 | Multi-feature xG model initial integration (distance/angle/pressure/assist blend) | DOING |
| 2025-08-09 | Batch | Script batch expandido (tipos passe, drible, launch) | DONE |
| 2025-08-09 | Batch | Script batch ampliado p/ métricas de habilidades | DONE |

## 9. Referências Cruzadas
- Proposta completa: `docs/simulation_refactor_proposal.md`
- Habilidades & Roles: `docs/abilities_and_roles.md`

---
(Manter este arquivo enxuto; detalhes conceituais permanecem na proposta.)

## Próxima Ação Imediata
- Investigar por que ENG final < non-ENG (provável baixa amostra GK/roles) antes de recalibrar peso stamina (6.4).
