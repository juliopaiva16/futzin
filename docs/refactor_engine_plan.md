# Plano de Refactor & Evolução Roguelike (LLM-Oriented)

Documento de planejamento incremental para transformar o motor atual (micro‑ações) + app em base modular com meta loop roguelike. Uso: servir como roteiro vivo (esta página) e dividir tarefas para YAML `progress/*.yaml` (estado). Mantém snapshot do presente, objetivos, fases, métricas de guarda e decisões.

---
## 1. Escopo do Refactor (OUT / IN)
IN:
- Extração de serviços: Probabilidades, Registro de Habilidades, Hooks Pré/Pós Partida.
- Modularização domínio vs meta (temporada, economia, pacotes, progressão).
- Persistência estruturada (SeasonState, EconomyState, Roster).
- Base para divergência estatística multi-divisão.
- Preparação para raridade, XP, lesões, química.

OUT (adiado):
- PvP em tempo real.
- UI polida de narrativa/feeds ricos.
- Modo pênaltis & set pieces avançados.
- Infra multi-isolate/performance paralela.

---
## 2. Snapshot Arquitetura Atual (Resumo Curto)
Camadas:
1. Domínio: `entities.dart`, `engine_params.dart`, `match_engine_*`, helpers & logging.
2. UI: páginas Hub, Mercado, Gestão, Partida, Widgets (Pitch, Momentum).
3. Automação: batch + update métricas.
Gaps principais: ausência de Season loop, persistência ampliada, economia, evolução jogadores, duplicações (xG/intercept), abilities espalhadas.

---
## 3. Objetivos Principais (SMART)
| Objetivo | Métrica Sucesso | Deadline Indicativa |
|----------|-----------------|---------------------|
| Unificar prob/xG/intercept em serviço | Delta métricas < 1% | Fase 0 |
| Introduzir SeasonState persistente | Salva/carrega temporada | Fase 1 |
| Loop básico de 12 partidas + pontos | Tabela calculada | Fase 1 |
| Sistema de pacotes (draft 3 escolhas) | Pack aberto registra rarity | Fase 2 |
| Economia básica (recompensa vitória) | currency_gain_avg coletado | Fase 3 |
| Divergence Score implementado | score computado CI | Fase 4 |
| Raridade & XP scaffold | Distribuição 5 tiers | Fase 5 |
| Fadiga acumulada + lesão simples | injury_rate dentro banda | Fase 6 |
| Química leve (tags) | chemistry_bonus_avg >0 | Fase 7 |

---
## 4. Princípios Norteadores
- Single Source of Truth para parâmetros (continua em `engine_params.dart`).
- Serviços puros → testáveis isoladamente (ProbabilityService, AbilityRegistry, RewardCalculator).
- Camadas limpas: Engine não conhece economia / pacotes; meta adapta entrada/saída.
- Evolução incremental (cada fase mantém jogo jogável).
- Métricas guard rails antes de merge (batch curto rápido + baseline comparativo).

---
## 5. Novos Módulos Propostos
| Módulo | Responsabilidade | Arquivos Iniciais |
|--------|------------------|-------------------|
| probability/ | Cálculo xG, intercept, fatigue, forced shot | `probability_service.dart` |
| abilities/ | Registro & efeitos agregáveis | `ability_registry.dart` |
| meta/season/ | SeasonState, agenda, avanço | `season_state.dart` |
| meta/packs/ | PackType, DraftOffer, geração | `pack_models.dart` |
| meta/economy/ | EconomyState, RewardCalculator | `economy_state.dart`, `reward_calculator.dart` |
| meta/progression/ | XP, Level, TrainingPlan | `player_progress.dart` |
| meta/chemistry/ | Tags e bonuses | `chemistry.dart` |
| meta/injury/ | Lesões e fadiga acumulada | `injury_fatigue.dart` |
| persistence/ | Serialização & versionamento | `store.dart` |
| calibration/ | Divergence, baseline multi-divisão | `divergence_service.dart` |

---
## 6. Pipeline de Hooks (Alvo)
PreMatch:
1. Resolver lesões / indisponibilidades.
2. Aplicar treinamento concluído → atualizar atributos.
3. Calcular fatigue acumulada → derivar stamina inicial.
4. Calcular química (links ativos) → gerar modificadores.

PostMatch:
1. Atualizar SeasonState (resultado, pontos, rodada).
2. Economia (recompensas base + objetivos).
3. XP / progress (atribuir e acumular).
4. Fadiga acumulada & risco de lesão.
5. Gatilho de eventos meta (draft especial, oferta etc.).

---
## 7. Fases Detalhadas (Roadmap Técnico)
Fase 0 – Fundamentos
- Criar ProbabilityService + migrar chamadas (remover duplicações). 
- AbilityRegistry esqueleto (map code→effect lambda).

Fase 1 – Season Loop Básico
- SeasonState (12 partidas), persistência local mínima. 
- Adaptar UI: iniciar temporada, avançar rodada, exibir pontos.

Fase 2 – Packs & Draft
- PackType + geração 3 opções (raridade placeholder). 
- Tela modal seleção; atualiza roster.

Fase 3 – Economia
- Currency + RewardCalculator (win/draw/loss). 
- Loja simples (comprar pack).

Fase 4 – Divergência & Batch Meta
- DivergenceService (RMS normalizado). 
- Baseline JSON + integração CI local script.

Fase 5 – Raridade & XP
- PlayerRarity + ranges; XP ganho por minutos. 
- LevelUp sem buffs extras iniciais.

Fase 6 – Fadiga & Lesões
- FatigueReserve & thresholds; Injury model com matchesOut. 
- PreMatch aplica debuff/skip.

Fase 7 – Química
- Tags (nacionalidade/estilo). 
- Bonus pequeno (ex: +1% attack se trio ativo).

Fase 8 – Refinamentos / Balancing
- Ajustar bandas, clamps, baseline multi-divisão; otimizações.

---
## 8. Métricas de Guarda (Baseline & Novas)
| Métrica | Banda / Objetivo | Fase Introdução |
|---------|------------------|-----------------|
| goals_avg | 2.4–3.2 | 0 |
| pass_pct | 75–88 | 0 |
| xg_avg | ~ goals_avg ±0.15 | 0 |
| divergence_score | <=0.40 (warn) | 4 |
| currency_gain_avg | Estável; var <10% baseline | 3 |
| matches_per_pack | 2–4 | 3 |
| injury_rate | 0.08–0.18 / season | 6 |
| fatigue90_mean_over_season | >=0.65 | 6 |
| xp_gain_avg | Suporta level curve alvo | 5 |
| rarity_distribution | Pyramidal (common dominante) | 2 |
| chemistry_bonus_avg | 0–0.04 range | 7 |

---
## 9. Estrutura de Testes
- Unit: ProbabilityService, AbilityRegistry, RewardCalculator, DivergenceService.
- Integration: Season progression (3 partidas), Pack opening, Economy accumulation.
- Regression Batch: Pós cada fase → comparar métricas core vs baseline.

---
## 10. Riscos & Mitigações
| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Duplicação lógica persiste | Drift estatístico | Serviço único + testes snapshot |
| Complexidade meta explode | Atraso roadmap | Fases pequenas + métricas early |
| Economia inflaciona | Perde senso de progressão | Sinks (treino) + divergence meta |
| Lesões frustram | Retenção menor | Taxas moderadas + feedback UI |
| Química vira pay-to-win | Balance quebrado | Caps & diminishing returns |

---
## 11. Decisões (Decision Log)
Formato sugerido (append-only):
```
DD-0001 | 2025-08-12 | Serviço único prob | Unificar xG/intercept; menos drift | Aprovado
```
Adicionar seção real conforme decisões forem tomadas.

---
## 12. Checklist de Cada PR
1. Código + testes verdes.
2. Nenhum magic number fora `engine_params.dart` (exceto UI).
3. YAML(s) alterados → updated + notas sucintas.
4. Batch rápido (N pequeno) sem romper bandas.
5. Docs: se API pública muda, atualizar esta página ou docs específicos.

---
## 13. Template de Modelo (Exemplo PlayerProgress)
```dart
class PlayerProgress {
  final String playerId;
  final int level;
  final double xp;
  final double xpForNext;
  final int pendingPoints; // para distribuir em atributos
  final int matchesSinceInjury;
  const PlayerProgress({
    required this.playerId,
    required this.level,
    required this.xp,
    required this.xpForNext,
    required this.pendingPoints,
    required this.matchesSinceInjury,
  });

  PlayerProgress gain(double gained) {
    final newXp = xp + gained;
    if (newXp < xpForNext) return copyWith(xp: newXp);
    return copyWith(
      level: level + 1,
      xp: newXp - xpForNext,
      xpForNext: xpForNext * 1.15, // crescimento exponencial leve
      pendingPoints: pendingPoints + 1,
    );
  }

  PlayerProgress copyWith({
    String? playerId,
    int? level,
    double? xp,
    double? xpForNext,
    int? pendingPoints,
    int? matchesSinceInjury,
  }) => PlayerProgress(
        playerId: playerId ?? this.playerId,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        xpForNext: xpForNext ?? this.xpForNext,
        pendingPoints: pendingPoints ?? this.pendingPoints,
        matchesSinceInjury: matchesSinceInjury ?? this.matchesSinceInjury,
      );
}
```

---
## 14. Próximos Passos Imediatos (Fase 0)
- Adicionar ProbabilityService (copiar lógica única + testes comparativos).
- Criar AbilityRegistry com efeitos existentes (VIS, PAS, DRB, FIN...).
- Atualizar progress `engine.yaml` e criar novas fases em `meta_game.yaml`.

---
## 15. Manutenção do Documento
Este arquivo não guarda estado vivo (isso é função YAML). Atualizações aqui apenas para nova estrutura, decisões e princípios. Sempre referenciar IDs de fases dos YAML para consistência.

---
Fim do plano.
