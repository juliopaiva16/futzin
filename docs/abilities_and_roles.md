# Habilidades Especiais e Micro Categorias (Roles)

Este documento descreve todas as habilidades especiais atuais (8 originais + 20 novas específicas por macro posição) e as micro categorias (roles) propostas para enriquecer a simulação do Futzin. Inclui o impacto mecânico sugerido para futura implementação. Valores percentuais/multiplicadores são cumulativos antes de clamps finais.

## Sumário
- [1. Habilidades Originais](#1-habilidades-originais)
- [2. Novas Habilidades por Macro Posição](#2-novas-habilidades-por-macro-posição)
  - [2.1 Goleiro (GK)](#21-goleiro-gk)
  - [2.2 Defensor (DEF)](#22-defensor-def)
  - [2.3 Meio-campista (MID)](#23-meio-campista-mid)
  - [2.4 Atacante (FWD)](#24-atacante-fwd)
- [3. Resumo de Áreas Impactadas](#3-resumo-de-áreas-impactadas)
- [4. Micro Categorias (Roles)](#4-micro-categorias-roles)
  - [4.1 Goleiros](#41-goleiros)
  - [4.2 Defensores](#42-defensores)
  - [4.3 Meio-campistas](#43-meio-campistas)
  - [4.4 Atacantes](#44-atacantes)
- [5. Ordem Recomendada de Aplicação dos Modificadores](#5-ordem-recomendada-de-aplicação-dos-modificadores)
- [6. Clamps & Segurança Numérica](#6-clamps--segurança-numérica)

---
## 1. Habilidades Originais
| Código | Nome | Efeito Descritivo | Impacto Mecânico Proposto |
|--------|------|-------------------|---------------------------|
| VIS | Visão Aguçada | Menos interceptações. | interceptChance *0.90; quality +=0.01 se último passador VIS. |
| PAS | Passe na Medida | Passes mais precisos, leve bônus xG. | xg *=1.05 se passador ou finalizador PAS. |
| DRB | Drible Sagaz | Pode alongar jogadas. | 25% chance +1 passe (limite máx ajustado); closeChance *0.95 se portador DRB. |
| FIN | Finalização Letal | Mais gols. | pGoal *1.08 (cap 0.85). |
| WALL | Muralha | Linha defensiva fortalecida. | defenseAdj *(1+0.01*nWALL); pGoal adversário * (1-0.01*nWALL). |
| ENG | Motor Inesgotável | Cansa menos. | fatigue *0.80. |
| CAT | Gato no Gol | Mais defesas decisivas. | pGoal atacante *0.90 quando GK CAT. |
| CAP | Capitão Inspirador | Bônus global. | attackAdj & defenseAdj *1.02 (uma vez). |

---
## 2. Novas Habilidades por Macro Posição
### 2.1 Goleiro (GK)
| Código | Nome | Descrição | Impacto Proposto |
|--------|------|-----------|------------------|
| REF | Reflexos Felinos | Defesas rápidas em chutes de curta distância. | pGoal *=0.93 para chutes com xg <=0.35. |
| COM | Comando da Área | Domina bolas altas e organização. | pGoal geral *=0.97; (futuro: reduzir passes extras após cruzamentos). |
| SWS | Sweeper Keeper | Atua adiantado, corta lançamentos. | closeChance adversária inicial -5% se lineHeight>0.55; fatigue GK *1.05. |
| DST | Distribuição Precisa | Inicia construção com qualidade. | Se disputa de rating equilibrada (|a-b| <5%) pA +=0.01; interceptChance primeiro passe -10%. |
| PEN | Especialista em Pênaltis | Brilha em penalidades. | (Reserva para modo pênaltis futuro). |

### 2.2 Defensor (DEF)
| Código | Nome | Descrição | Impacto Proposto |
|--------|------|-----------|------------------|
| TKL | Desarme Cirúrgico | Desarmes limpos e frequentes. | interceptChance *1.08 quando este defensor elegível; foulChance +0.02. |
| MRK | Marcação Implacável | Pressiona sem dar espaço. | closeChance +=0.03; pGoal pós-xg *=0.97. |
| AER | Dominância Aérea | Ganha duelos aéreos decisivos. | pGoal *=0.95 em chutes xg>0.40. |
| BLK | Bloqueador | Bloqueia finalizações. | 15% dos chutes viram "bloqueado" (texto); reduz pGoal adicional 0.01 (opcional). |
| BPD | Construtor | Sai jogando com qualidade. | 30% chance +1 passe extra (limite 3); interceptChance sofrida +5%. |

### 2.3 Meio-campista (MID)
| Código | Nome | Descrição | Impacto Proposto |
|--------|------|-----------|------------------|
| DLP | Armador Recúado | Orquestra desde trás. | quality +=0.015 se inicia; interceptChance primeiro passe -0.02. |
| B2B | Box-to-Box | Cobertura campo todo. | fatigue *0.90; defenseAdj +=0.2 (cap +0.6 cumulativo). |
| CAM | Criador Central | Último passe refinado. | xg +=0.015 se último passador CAM; passCount base +1 até 60'. |
| ANC | Volante Âncora | Protege a zaga. | closeChance contra adversário *1.07; reduz poss adversária efetiva (~-1s). |
| WNG | Ala Criativo | Alarga o campo. | width efetiva +0.02; interceptChance passes largos *0.95. |

### 2.4 Atacante (FWD)
| Código | Nome | Descrição | Impacto Proposto |
|--------|------|-----------|------------------|
| MOV | Movimentação Inteligente | Desmarca-se com facilidade. | closeChance -0.02; quality +=0.01. |
| HDR | Cabeceador | Letal no alto. | pGoal *1.05 quando xg>=0.30 (cap sinérgico FIN/HDR 1.10). |
| SPR | Velocidade Explosiva | Aceleração curta. | closeChance -0.03 nos 2 primeiros eventos; fatigue *1.05. |
| PCH | Pivô | Segura e distribui. | passCount máx 3 se ele inicia; quality colegas +0.005. |
| CLT | Clutch | Decide em momentos finais. | pGoal *1.07 após 75'. |

---
## 3. Resumo de Áreas Impactadas
- Fatigue: ENG (-20%), B2B (-10%), SPR (+5%), SWS (+5%).
- Sequência (passes): DRB, BPD, CAM, PCH, (SWS/REF indiretos), DRB chance extra.
- Interceptação: VIS (-10%), PAS (-5%), DLP (-2%), WNG (-5%), TKL (+8%), BPD (+5%).
- closeChance (fechar ataque cedo): DRB (-5%), MOV (-2%), SPR (-3%), SWS (-5% condicional), MRK (+3%), ANC (+7%), MRK/AER defensivos.
- quality/xg: VIS (+0.01), PAS (xg *1.05), DLP (+0.015), CAM (+0.015), MOV (+0.01), PCH (+0.005 colegas), FIN indireto via pGoal, HDR pGoal condicional.
- pGoal: FIN (+8%), CAT (-10% contra), WALL (-1% cada), MRK (-3%), AER (-5% alto xg), REF (-7% baixo xg), HDR (+5% alto xg), CLT (+7% late), CAP (+2% via ratings), COM (-3%), ANC (indireto via fechar ataques). 
- Team Ratings pré-probabilidades: WALL, CAP, B2B, WNG (width), roles específicos (ver abaixo).

---
## 4. Micro Categorias (Roles)
Cada jogador pertence a uma macro posição (GK, DEF, MID, FWD) e pode receber um Role (micro categoria) que altera pesos base de attack/defense ou variáveis auxiliares.

### 4.1 Goleiros
| Código | Nome | Ajustes |
|--------|------|---------|
| STD | Tradicional | Base. |
| STS | Shot-Stopper | gkD *1.05; reduz pA pequeno (-0.005). |
| SWSR | Sweeper | Sinergia com SWS habilidade (efeito cumulativo). |
| DSTB | Distribuidor | attackAdj *1.01; gkD *0.97. |
| CMD | Comando | gkD *1.02; pGoal alto -2%. |

### 4.2 Defensores
| Código | Nome | Ajustes |
|--------|------|---------|
| CB | Zagueiro Central | defense +5%. |
| STP | Stopper | defense +7%; foulChance +2%. |
| LIB | Líbero | attack +2%; defense -2%. |
| FBW | Lateral Ofensivo | attack +3%; defense -3%; width +0.01. |
| FBD | Lateral Defensivo | defense +4%; attack -2%. |

### 4.3 Meio-campistas
| Código | Nome | Ajustes |
|--------|------|---------|
| ANC | Volante Âncora | defense +6%; attack -3%. |
| B2B | Box-to-Box | fatigue -5%; attack +2%; defense +2%. |
| CM | Meia Central | Neutro. |
| AP | Meia de Ligação | attack +4%; interceptChance passes +1%. |
| AM | Meia Atacante | attack +6%; defense -4%. |
| WM | Meia Lateral | width +0.015; attack +3%; defense -2%. |
| WB | Ala (Wing-Back) | attack +2%; defense +2%; fatigue +3%. |

### 4.4 Atacantes
| Código | Nome | Ajustes |
|--------|------|---------|
| ST | Centroavante | attack +5%. |
| F9 | Falso 9 | attack +3%; defesa +1%; contribui como MID parcial. |
| WG | Ponta | width +0.02; attack +4%; defense -3%. |
| IW | Ponta Invertido | attack +4%; quality central +0.005. |
| SS | Segundo Atacante | attack +3%; chance +1 passe (30%). |
| PC | Poacher | pGoal +3%; passes extras não aplicam. |

---
## 5. Ordem Recomendada de Aplicação dos Modificadores
1. Base efetiva por jogador: baseRating * staminaEffect.
2. Aplicar Role (micro categoria) ao componente (attack/defense) individual.
3. Agregar por linha (FWD/MID/DEF/GK) e compor fórmulas de attack/defense de time.
4. Aplicar habilidades que afetam ratings agregados (WALL, CAP, B2B, etc.).
5. Aplicar ajustes táticos (bias, width, lineHeight, pressing).
6. Durante sequência: calcular closeChance, interceptChance ajustando por habilidades/roles dinâmicos.
7. Calcular quality, xg -> aplicar habilidades de criação/finalização (VIS, PAS, DLP, CAM, MOV, PCH, FIN, HDR, etc.).
8. Calcular pGoal base -> aplicar habilidades defensivas/ofensivas finais (FIN, CAT, WALL, MRK, AER, REF, HDR, CLT, COM, PC).
9. Clamps e registro de evento.

---
## 6. Clamps & Segurança Numérica
- quality clamp: [0.0, 1.0]; incrementos pequenos (<= +0.04 cumulados típicos).
- xg clamp atual sugerido: [0.03, 0.70] após modificadores.
- pGoal clamp: [0.02, 0.85] (antes de HDR+FIN sinérgico cap 0.90 se desejado).
- Multiplicadores cumulativos: aplicar em sequência e clampar.
- Manter double explícito e cast/clamp em offsets gráficos.

---
Futuro: adicionar tradução EN/PT para nomes/descrições novas nas ARB antes da implementação.
