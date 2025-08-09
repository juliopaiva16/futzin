# Proposta de Refatoração da Engine de Simulação (Modelo de Grafo)

Este documento descreve uma refatoração da engine para um modelo baseado em teoria de grafos, integrando micro categorias (roles) e habilidades especiais, mantendo simplicidade lúdica e previsibilidade controlada. Estruturado para implementação incremental.

## 1. Objetivos
- Aumentar granularidade (posicionamento espacial, decisões por jogador).
- Tornar ações emergentes: passes/dribles/chutes resultam de estado local (arestas) e atributos.
- Integrar habilidades e roles como modificadores localizados em fases claras do pipeline probabilístico.
- Manter ritmo simplificado (eventos de alto nível agregam micro-ticks) para UX atual.
- Facilitar tuning estatístico (xG médio, chutes, passes decisivos, posse). 

## 2. Resumo do Modelo Atual (Problemas)
| Aspecto | Atual | Limitação |
|---------|-------|-----------|
| Sequência | Bloco sintético (texto + opcional shot) | Pouca variação espacial / decisão granular |
| Probabilidade ataque | Razão ataqueAdj/defenseAdj | Sem contexto local (distância, linhas de passe) |
| Passes | Número fixo (0–2) | Não modela rede de passes / interceptações multi-agente |
| xG | Função rating agregado | Não considera geometria (distância/ângulo) |
| Habilidades | Apenas definidas | Não influenciam engine |
| Stamina | Decaimento uniforme | Não interage com estilos/roles |

## 3. Nova Abordagem (Visão Geral)
Estado por micro-tick (Δt ~0.5s lógico) atualizado em ciclos, agregado em eventos de “minuto” textual. Jogadores são nós com posição contínua (campo normalizado 0..1 X (largura), 0..1 Y (profundidade ataque time A left→right)). A posse é um único nó portador. Arestas são candidatas de passe direcionadas (ponderadas) recalculadas dinamicamente.

Pipeline micro-tick:
1. Atualizar posições (movimento para zonas tática + jitter + objetivos contextuais).
2. Se bola livre → disputa (nearest contest weighted por pace+technique+stamina).
3. Construir subgrafo ofensivo (arestas portador→colegas) e defensivo (defensores em cones de intercepção / tackle raio).
4. Gerar ações possíveis do portador (scores → softmax → escolha).
5. Resolver ação (passe/drible/chute/etc) com probabilidades derivadas de atributos + contexto.
6. Aplicar efeitos stamina/fadiga/skills.
7. Emitir/logar eventos agregados após N micro-ticks (~representa 1 “momento” no minute loop).

## 4. Estruturas de Dados
```dart
class PlayerNode {
  String id;
  TeamSide side; // A ou B
  Position macro; // GK/DEF/MID/FWD
  Role role;      // micro categoria
  Set<String> abilities; // códigos
  double stamina; // 0..100
  double x; // 0..1 largura
  double y; // 0..1 profundidade (A ataca +Y)
  bool hasBall;
  CachedAttrs eff; // atributos efetivos pós stamina/role/habilidades
}

class Edge { // Passe candidato
  PlayerNode from;
  PlayerNode to;
  double dist; // euclidiana
  double angle; // em relação ao gol adversário
  double weight; // prob relativo de seleção
  bool isLong;
}

class MatchGraph {
  List<PlayerNode> nodes;
  Map<String,List<Edge>> outgoing;
  SpatialIndex grid; // consulta rápida de vizinhos
}
```

## 5. Sistema de Coordenadas
- Campo normalizado 1.0 x 1.0 (facilita painters existentes).
- Largura efetiva influenciada por tactics.width + roles (ex: WNG, WG).
- lineHeight desloca linhas DEF/MID/FWD no eixo Y.
- GK fixo próximo da linha de fundo (y≈0.02 ou 0.98 dependendo do lado).

## 6. Arestas de Passe
Critérios de inclusão:
- dist ≤ Dmax (curto) ou dist ≤ Lmax (longo); ex: Dmax=0.22, Lmax=0.55.
- Sem bloqueio crítico: Nenhum defensor com distância perpendicular < dBlock (≈0.015 + scaling) e projetado internamente ao segmento > threshold.

Peso base da aresta:
```
w = baseType * fDist * fAngle * fPassing * fReceiver * fPressure * fStamina * fAbilities

fDist = exp(-α * dist) (α≈4.0 para curtos, 2.0 para longos)
fAngle = 1 + γ*(cos(thetaToGoal) - 0.5) (γ≈0.3) // encoraja progressão
fPassing = (0.5*passer.passing + 0.3*passer.vision + 0.2*passer.technique)/100
fReceiver = (0.6*receiver.technique + 0.4*receiver.controlProxy)/100
fPressure = 1 - clamp(pressureLocal, 0, 0.5)
```
Modificadores de habilidades:
- PAS: w *=1.05 (curtos) / 1.02 (longos)
- VIS: w *=1.05 (ângulo progressivo thetaToGoal >0)
- BPD/DLP/AP: w *=1.03 para passes médios/verticais
- PCH (se receptor): w *=1.03

Normalização: Para seleção do alvo dentro da ação “Passe”: P(edge)= w^β / Σ w^β (β≈1.2 reforça top).

## 7. Conjunto de Ações & Scoring
Ações candidatas A = {PassCurto, PassLongo, Drible, Conduzir, Chutar, Lançamento, Recuar, ManterPosse} (filtrar indisponíveis).

Score geral:
```
score(a)= Σ_k (attr_k_norm * peso_k(a)) + contexto(a) + habilidades(a) + ruído(σ=0.03)
P(a)=softmax(λ*score(a)) (λ≈1.0)
```
Tabela de pesos principais (exemplo inicial):
| Ação | passing | vision | technique | pace | strength | attack | defense | distânciaGol (neg) | pressão (neg) |
|------|---------|--------|-----------|------|----------|--------|---------|---------------------|---------------|
| PassCurto | 0.30 | 0.25 | 0.15 | 0.05 | 0.00 | 0.05 | 0.00 | 0.00 | 0.25 |
| PassLongo | 0.28 | 0.28 | 0.20 | 0.05 | 0.04 | 0.05 | 0.00 | 0.00 | 0.25 |
| Drible    | 0.05 | 0.05 | 0.35 | 0.30 | 0.05 | 0.10 | 0.00 | 0.05 | 0.25 |
| Conduzir  | 0.10 | 0.10 | 0.20 | 0.25 | 0.05 | 0.15 | 0.00 | 0.05 | 0.20 |
| Chutar    | 0.05 | 0.05 | 0.15 | 0.10 | 0.05 | 0.50 | 0.00 | 0.30 | 0.15 |
| Lançamento| 0.30 | 0.25 | 0.20 | 0.05 | 0.05 | 0.10 | 0.00 | 0.00 | 0.30 |
| Recuar    | 0.20 | 0.25 | 0.05 | 0.00 | 0.00 | -0.10| 0.10 | -0.05| 0.05 |
| Manter    | 0.10 | 0.10 | 0.15 | 0.00 | 0.00 | -0.15| 0.05 | -0.05| 0.05 |

Contexto adicional:
- Convergência para objetivo: se distânciaGol < 0.22 aumenta peso de Chutar.
- Sequência longa sem progresso (n passes laterais) -> penaliza manter.
- Pressão alta (>0.6) aumenta prob de passe curto/recuo; reduz passe longo/drible.

Habilidades/roles (exemplos):
- DRB: +0.08 score Drible.
- FIN: +0.06 score Chutar (quando distânciaGol < Rfin).
- MOV: +0.04 Chutar; -0.02 PassCurto (tende a buscar desmarque finalizador).
- PCH: +0.05 Recuar (para “pivot”) se outros avançam; +0.03 PassCurto.
- DLP/AP: +0.05 PassLongo/PassCurto conforme progressão.
- SPR: +0.05 Drible/Conduzir se espaço livre > threshold.

## 8. Resolução de Passe
```
probSucessoPasse = base
  * passerPassingEff
  * receiverControlEff
  * exp(-κ * dist)
  * (1 - pressãoTrajetória)
  * staminaFactorPasser
  * (1 + bonusHabilidades)
```
Interceptação multi-agente:
```
Para cada defensor k na zona do segmento:
  p_k = baseIntercept * defenseEff_k * (1 - fadiga_k) * geometria(k,segmento)
P_intercept = 1 - Π_k (1 - p_k)
Resultado:
  Sucesso se U < probSucessoPasse*(1 - P_intercept)
  Se U < probSucessoPasse mas evento em faixa [probSucessoPasse*(1 - P_intercept), probSucessoPasse] => interceptado (crédito ao k com maior p_k)
  Se U ≥ probSucessoPasse => passe errado (bola livre → disputa)
```
Habilidades:
- VIS: p_k *=0.92.
- PAS: probSucessoPasse *=1.05 (curto)/1.03 (longo).
- TKL: p_k *=1.08 para defensor com TKL.
- BPD (contra): p_k *=1.05 se interceptando passe longo do BPD (risco).

## 9. Drible / Condução
Defensores em raio R_tackle (~0.06):
```
probDrible = techniqueEff*0.45 + paceEff*0.30 + strengthEff*0.10 + random(±0.05)
resist = max_k(defenseEff_k*0.40 + pressingLocal*0.30 + paceEff_k*0.20)
probSucesso = clamp(0.05 + (probDrible - resist), 0.05, 0.85)
```
Falha → perda (defensor com maior resist ganha posse) + 12% chance de falta se pressingLocal alto; TKL aumenta +4pp a falta; DRB reduz resist em -0.03.

## 10. Cálculo de Chute / xG
Componentes:
- Geometria: distGol (d), ânguloAbertura (θ), bloqueadores no cone.
```
q_geo = w_d * (1 - d/dMax) + w_ang * (θ/θMax) - w_blk * B (proporção de área bloqueada)
q_attr = attackEff*α + techniqueEff*β + (MOV? +0.02) + (PCH? +0.01) + (HDR se cabeceio condic.)
xg_raw = base + c1*q_geo + c2*q_attr + ruído(±0.02)
```
Habilidades finais:
- FIN: xg_raw *=1.05 ou pGoal *=1.08 (escolher um para não dupla-contar) → preferir pós.
- HDR: se cabeceio (condição: origem de cruzamento longo + altura) pGoal *=1.05.
- REF/CAT/COM/AER/WALL: ajustam pSave ou pGoal pós-bloco.

GK Save Model:
```
pSave_base = gkDefenseEff*0.60 + posicionamentoFactor*0.20 + reflexFactor*0.20
Ajustes habilidades:
 CAT: pSave_base *=1.05
 REF: se xg_raw <=0.35 -> pSave_base*=1.07
 COM: pSave_base*=1.03 (ou redução pGoal)
```
pGoal = clamp(xg_raw * (1 - pSave_base) * modsOfensivos * modsDefensivos, 0.02, 0.85)
FIN/HDR sinérgico: cap 0.90.

## 11. Stamina & Atributos Efetivos
```
staminaEffect = 0.60 + 0.40*(staminaPct)
attrEff = baseAttr * staminaEffect * roleMult * abilityMult
```
Fadiga por tick:
```
fatigueTick = (base + tempoFactor + pressingFactor + sprintFactor)* (1 - ENG*0.20 - B2B*0.10) * (1 + SPR*0.05 + SWS*0.05)
```
Atualização a cada minuto lógico agrega ticks (média) para consistência anterior.

## 12. Roles (Aplicação)
Aplicar multiplicadores role antes de agregação por linha:
- Ex: CB defenseEff *=1.05; AP passingEff *=1.04; ST attackEff *=1.05 etc.
- F9 adiciona 30% do attackEff a midAttack pool (flex). 

## 13. Habilidades (Mapa de Fase)
| Fase | Habilidade | Efeito |
|------|------------|--------|
| Arestas | VIS, PAS, BPD, DLP, AP, PCH | Ajustam w / seleção alvo |
| Ação scoring | DRB, MOV, SPR, FIN, PCH, CAM | Ajuste de score |
| Passe sucesso | PAS, VIS | +sucesso | 
| Intercept | TKL, WALL (leve - via defenseEff), VIS (-), BPD (+ contra) |
| Drible | DRB, SPR, TKL, MRK | Resist vs prob |
| xG pré | CAM, MOV, PCH, DLP | +quality/xg |
| pSave | CAT, REF, COM, AER | Ajusta pSave_base |
| pGoal pós | FIN, HDR, CLT (>75’), WALL (-1% cada), MRK (-3%), AER (-5% xg alto), REF/CAT/COM | Pós-cálculo |
| Fatigue | ENG (-20%), B2B (-10%), SPR/SWS (+5%) |
| Ratings base | CAP (+2%), WALL (+1% each), B2B (+def), ANC (closeChance) |

## 14. Emissão de Eventos
Agrupar sequência de micro-ticks (ex: até concluir ação “terminal”: intercept, chute, falta, drible perdido). Construir descrição textual:
- “Sequência rápida: A → B → C, chute de C (xG 0.27) defendido.”
Manter fields já usados (minute, xgA/B acumulados, momentum side por cada evento terminal).

## 15. Roadmap Incremental
1. Infra posição & roles (coordenadas + Role enum) sem mudar lógica antiga.
2. Substituir _buildAttackSequence por micro motor de passes (apenas PassCurto + Chute simples).
3. Adicionar arestas ponderadas + interceptação multi-defensor.
4. Introduzir ações adicionais (Drible, PassLongo, Recuar, Manter).
5. Integrar habilidades originais + novas (faseada por blocos: passes, dribles, finalização, defesa).
6. Portar stamina nova e recalibrar ratings.
7. Ajustar momentum/xG para manter ranges históricos.
8. UI: se opcional, flag “Experimental Graph Engine”.
9. Remover engine antiga após validação.

## 16. Métricas & Tuning
Registrar por partida:
- passes curtos/longos, % sucesso.
- dribles tentados/sucesso.
- chutes, xG, gols.
- interceptações por jogador.
- distribuição de prob. ações (heatmap). 
Automatizar teste: rodar 500 sims seedados e comparar contra faixas alvo (scripts).

## 17. Clamps & Estabilidade
- Garantir clamps após cada multiplicador (xg, pGoal) para evitar explosão.
- β e λ ajustáveis via config para calibrar entropia de decisão (mais/menos aleatório).
- Introduzir função de suavização: w' = (w + ε) / Σ(w + ε) (ε pequeno) para evitar zero absoluto.

## 18. Performance
- 22 nós: recalcular arestas <= 2ms (Dart) com pruning por dist.
- SpatialIndex: grid 10x6 -> bucket queries O(1) expected.
- Micro-tick batch: processar 4–6 micro-ticks antes de flush textual (reduz overhead de stream).

## 19. Persistência & Backward Compatibility
- Acrescentar em Player JSON: role (string), abilities extendidas.
- Versão de estado: stateVersion=2; fallback -> role default macro.

## 20. Riscos & Mitigações
| Risco | Mitigação |
|-------|-----------|
| Complexidade tuning | Param table central / YAML para ajustes sem code change |
| Performance UI web | Batching micro-ticks / reduzir repaints pitch |
| Desbalance habilidades | Flag debug multiplicadores + testes estatísticos |
| Regressão xG | Script comparativo antes/depois |

## 21. Próximos Passos para Implementação
- Criar enums: Role, Ability (ou manter codes) + mapa estático de efeitos.
- Introduzir PlayerNode ext (adapter a partir de Player existente).
- Implementar módulo graph_engine.dart ao lado da engine atual.
- Fase 1: stub que apenas traduz eventos da engine antiga para coordenadas para validar rendering.
- Fase 2+: migrar lógica conforme roadmap.

## 22. Parâmetros Iniciais Centralizados (Sugestão)
```dart
class EngineParams {
  static const double passShortMaxDist = 0.22;
  static const double passLongMaxDist = 0.55;
  static const double edgeAlphaShort = 4.0; // fDist
  static const double edgeAlphaLong = 2.0;
  static const double interceptBase = 0.07; // escalar por defenseEff
  static const double tackleRadius = 0.06;
  static const double pressureRadius = 0.10;
  static const double staminaBaseDecayPerMin = 0.10; // baseline 0..1
  static const double shotMaxDist = 0.35; // normalizado
}
```

## 23. Testes Unitários Alvo
- Probabilidade de seleção de ação respeita ranking de score monotonicamente (quanto maior score, maior P média em 10k amostras).
- Intercept multi-defensor: P_intercept cresce com #defensores.
- Efeito VIS reduz intercept em ~10% relativo medido em cenários fixos.
- FIN eleva pGoal esperado dentro do cap.
- Stamina: após 90 min, jogador ENG retém ~15pp stamina adicional vs baseline.

## 24. Conclusão
Modelo de grafo fornece flexibilidade e transparência; abordagem incremental reduz risco; parametrização central facilita balance. Após estabilização estatística, engine antiga pode ser deprecada com flag de fallback temporária.

---
(Documento vivo — atualizar conforme tuning real.)
