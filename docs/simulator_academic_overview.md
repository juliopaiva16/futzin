# Futzin Football Match Simulator – Academic Overview

> Versão: 2025-08-10
> Escopo: descreve formalmente (i) motor legacy minute/sequence, (ii) motor gráfico incremental, (iii) instrumentação estatística, (iv) fundações para transição a modelo Markov / MDP leve.

---
## 1. Conjuntos Fundamentais

### 1.1 Jogadores
Cada jogador \(p\) possui atributos escala 0–100:
\[ A_p, D_p, S_p, Pa_p, Tec_p, Sta_p, Str_p \]
(Esses representam Attack, Defense, Pace, Passing, Technique, Stamina, Strength.)

Habilidades (abilities) \(H\) são um conjunto discreto \(H_p \subseteq \{\text{VIS},\text{PAS},\text{DRB},\text{FIN},\text{WALL},\text{CAT},\text{CAP},\text{ENG}, ...\}\) que induzem modificadores multiplicativos ou aditivos em certas fórmulas (detalhados conforme aparecem).

### 1.2 Tática de Time
Para cada time \(T\):
\[ \tau_T = (\text{attackBias}, \text{width}, \text{tempo}, \text{pressing}) \in [0,1]^4. \]

### 1.3 Formação
Uma formação define partições de linhas (DEF, MID, FWD) e afeta pesos de agregação (ex: 4-2-3-1 vs 4-3-3 muda distribuição de MID/FWD).

---
## 2. Ratings Agregados de Time
Definimos subconjuntos de jogadores por macro posição: \(G(T), D(T), M(T), F(T)\).

### 2.1 Fatores de Stamina
Fator de efetividade por jogador:
\[ f^{sta}_p = 0.60 + 0.40\, \frac{Sta^{curr}_p}{100}. \]
Atributo efetivo genérico para ataque ou defesa: \(X^{eff}_p = X_p \cdot f^{sta}_p\).

### 2.2 Rating Ofensivo
\[
R^{att}_T = w_F^{att} \sum_{p \in F(T)} A^{eff}_p + w_M^{att} \sum_{p \in M(T)} A^{eff}_p + w_D^{att} \sum_{p \in D(T)} A^{eff}_p.
\]
Pesos default (engine legacy): \(w_F^{att}=1.0, w_M^{att}=0.65, w_D^{att}=0.20\).

### 2.3 Rating Defensivo
\[
R^{def}_T = w_D^{def}\! \sum_{p \in D(T)} D^{eff}_p + w_M^{def}\! \sum_{p \in M(T)} D^{eff}_p + w_G^{def}\! \sum_{p \in G(T)} D^{eff}_p + w_F^{def}\! \sum_{p \in F(T)} D^{eff}_p
\]
com \(w_D^{def}=1.0, w_M^{def}=0.55, w_G^{def}=1.2, w_F^{def}=0.1\).

### 2.4 Ajustes Táticos
Aplicamos modificadores (simplificação):
\[ R^{att,adj}_T = R^{att}_T (1 + c_{ab} (attackBias_T-0.5) + c_{wd}(width_T-0.5) + c_{lh}(lineHeight_T-0.5)). \]
\[ R^{def,adj}_T = R^{def}_T (1 + c_{pr} \cdot pressing_T - c_{ab}' (attackBias_T-0.5)). \]
Constantes \(c_*\) empíricas calibradas (ex: \(c_{pr} \approx 0.06\)).

---
## 3. Loop de Minutos (Engine Legacy)
Cada minuto \(m\) classificamos em CALMO ou ATACANTE.

Probabilidade de minuto com sequência ofensiva para pelo menos um lado:
\[ P(\text{seq}) = p_0 + p_{tempo} \cdot \overline{tempo}, \quad \overline{tempo} = \tfrac{tempo_A + tempo_B}{2}. \]
Se não há sequência → posse dividida (~30s cada) e evento "calm minute".

Se há sequência, definimos chance do Time A atacar:
\[ P(A \text{ ataca}) = \frac{R^{att,adj}_A / R^{def,adj}_B}{R^{att,adj}_A / R^{def,adj}_B + R^{att,adj}_B / R^{def,adj}_A}. \]

---
## 4. Construção de Sequência (Legacy)
Dentro de uma sequência ofensiva, escolhe-se número de passes \(N_p\) com distribuição discreta centrada em:
\[ N_p \sim \text{Clamp}\Big(0, N_{max}, \; B + U(0,k) - 1\Big), \quad B = 1 + (tempo_{atk} + width_{atk}) c_{tw}. \]

A cada passe: probabilidade de interceptação
\[ P(\text{intercept}) = b_{int} + d_{int} \cdot \frac{R^{def,adj}_{def}}{R^{att,adj}_{atk} + R^{def,adj}_{def}}. \]

Após passes, um chute é avaliado.

### 4.1 Modelo Simplificado de xG (Legacy)
\[ xG = \text{Clamp}(xG_{base} + k_a \cdot q + \epsilon, xG_{min}, xG_{max}) \]
onde \( q = \frac{R^{att,adj}_{atk}}{R^{att,adj}_{atk}+R^{def,adj}_{def}} \) e \(\epsilon\) ruído uniforme centrado.

Probabilidade de gol:
\[ P(\text{gol}) = \text{Clamp}( xG \cdot (0.95 - k_{gk} \cdot s_{gk}), p_{g,min}, p_{g,max}) \]
com \( s_{gk} = D^{eff}_{GK}/100 \).

---
## 5. Motor Gráfico (Graph Engine)
Objetivo: micro-decisões de ação: \{shortPass, longPass, backPass, dribble, hold, launch, shot\} com pesos contextuais.

### 5.1 Distâncias & Congestionamento
Para um par emissor-receptor \((i,j)\):
\[ d_{ij} = \sqrt{(x_i - x_j)^2 + (y_i - y_j)^2}. \]
Peso base inverso:
\[ w_{ij}^{base} = \frac{1}{\alpha + d_{ij}}. \]
Penalidade de congestionamento avaliando defensores \(D\) em raio \(r_c\) ao ponto médio \(m_{ij}\):
\[ density = \sum_{d \in D, \; ||d - m_{ij}|| < r_c} \Big(1 - \frac{||d - m_{ij}||}{r_c}\Big). \]
\[ w_{ij} = w_{ij}^{base} (1 - \text{Clamp}(k_c \cdot density,0,\beta)). \]

### 5.2 Seleção de Ação
Ações possuem pesos iniciais \(W_a\). Exemplo (short vs long vs dribble):
\[ W_{short} = W_{short}^0 + 1_{holdBuff} k_{hold} + 1_{adaptive} k_{adap}. \]
\[ W_{dribble} = 1_{eligible} k_{drb} (1 + Tec/150) (1 + 1_{DRB}\,k_{DRB}). \]
\[ W_{long} = 1_{longRec} k_{long}. \]
Normalização:
\[ P(a) = \frac{W_a}{\sum_{b} W_b}. \]

### 5.3 Probabilidade de Interceptação (Uni + Multi)
Componente base (distância + defesa):
\[ p_{single} = p_0 + k_{def} \cdot \frac{R^{def,adj}_{def}}{R^{att,adj}_{atk}+R^{def,adj}_{def}} + k_d (d_{ij} - d_0). \]
Efeito multi-defensor: para cada defensor relevante \(d\): prob local \(p_d\) limitado e combinamos complemento:
\[ p_{multi} = 1 - \prod_{d} (1 - p_d). \]
Combinação híbrida (para long pass):
\[ p_{int} = (1-\lambda) p_{single} + \lambda p_{longModel}. \]
Aplicar habilidades (VIS reduz, WALL aumenta, PAS reduz curto, etc.).

### 5.4 Drible
Probabilidade de sucesso:
\[ p_{drb} = \text{Clamp}( b_{drb} + k_{tec} \tfrac{Tec_{atk}}{100} + k_{pace} \tfrac{(Pace_{atk}-Pace_{def})}{100} - k_{def} \tfrac{Def_{def}}{100} + 1_{DRB} k_{DRB}^{add}, p_{min}, p_{max}). \]

### 5.5 Chute (Graph)
Posicionamento relativo ao gol (eixo X normalizado): \(d_x = |x_{goal} - x_{atk}|\).
\[ xG = \text{Clamp}( xG_{base} + k_{blend}( \alpha q + (1-\alpha)(1-d_x)) + \epsilon, xG_{min}, xG_{max}). \]
Probabilidade de gol:
\[ p_{goal} = \text{Clamp}( xG (\gamma - k_{gk} s_{gk}) \cdot M_{FIN} \cdot M_{CAT}, p_{g,min}, p_{g,max}). \]
Onde multiplicadores de habilidade:
\[ M_{FIN} = (1 + k_{FIN})^{1_{FIN}}, \quad M_{CAT} = (1 - k_{CAT})^{1_{CAT \; do \; GK}}. \]

### 5.6 Pressão (Instrumentação)
Definimos \( pressure(p) = \text{Clamp}\Big( \frac{1}{n}\sum_{d \in D} \frac{1}{\|p-d\|}, 0, P_{max}\Big). \)
Binning futuro cria buckets para Markov.

---
## 6. Stamina & Fadiga
Decaimento por minuto (simplificado):
\[ Sta^{curr}_{p,m+1} = Sta^{curr}_{p,m} - ( c_0 + c_{tempo} tempo_T + c_{press} pressing_T + c_{action} A_{p,m} ) (1 - 1_{ENG} k_{ENG}). \]
Onde \(A_{p,m}\) codifica custo incremental de ações intensas (drible, sprint, long pass, launch).

---
## 7. Instrumentação (JSONL)
Cada ação logada como registro \(L\):
\[ L = (matchId, min, pid, ai, t, side, fromId, toId, (x,y)_{from}, (x,y)_{to}, preXg, xgDelta, shot?, goal?, dist, prs). \]

### 7.1 Métricas Derivadas
- Taxa de passe: \(\hat{p}_{pass} = \frac{\text{passes completos}}{\text{passes tentados}}\).
- Sucesso drible: \(\hat{p}_{drb} = \frac{\text{dribles sucesso}}{\text{dribles total}}\).
- Comprimento de posse: tamanho médio de \(\{ai: pid = k\}\).
- Histogramas distância passe/shot: binning uniforme ou custom edges.

---
## 8. Extensão Markov / MDP (Planejado)
### 8.1 Estado \(s\)
\[ s = (z, pres, stam_b, role, side, chainLen, scorePhase) \]
com discretizações definidas para cada componente.

### 8.2 Ações \(\mathcal{A}(s)\)
Subconjunto elegível de \{sp_fwd, sp_lat, back, long, dribble_fwd, dribble_lat, hold, launch, shot\} condicionado por zone/role.

### 8.3 Política Estocástica
Para cada ação \(a\): utilidade crua
\[ U_a = EV_{prog}(a|s) + k_{xg} EV_{xg}(a|s) - \lambda EV_{risk}(a|s) - \phi(pres) - \psi(stam_b). \]
Exploração via softmax temperatura \(\tau\):
\[ P(a|s) = \frac{e^{U_a/\tau}}{\sum_{b} e^{U_b/\tau}}. \]

### 8.4 Transições
\[ P(s'|s,a) = (1 - P_{turnover}(a|s)) P_{adv}(z'|z,a) P_{pres}(pres'|s,a) ... + P_{turnover}(a|s) P_{swapSide}(s'). \]

### 8.5 Valor (Opcional)
Iteração de valor aproximada:
\[ V^{(k+1)}(s) = \sum_{a} P(a|s) \Big( r(s,a) + \gamma \sum_{s'} P(s'|s,a) V^{(k)}(s') \Big). \]
Recompensa local:
\[ r(s,a) = k_{prog} prog(a|s) + k_{xg} xg(a|s) - k_{loss} turnoverProb(a|s). \]

---
## 9. Calibração Estatística
Objetivos (targets):
\[ passSucc \in [0.75,0.82], \quad xG_{total} \in [2.4,3.2], \quad goals_{total} \approx xG_{total}, \]
\[ dribbleRate \in [0.45,0.60], \quad dribbleAttempts \in [10,20], \quad shotVolume \approx 22. \]
Função de divergência (exemplo):
\[ D = \sum_{m \in Metrics} w_m \cdot \frac{| \hat{m} - m^{target}|}{m^{target}}. \]
Optimização manual (grid / coord ascent) sobre parâmetros \(\Theta = (k_{int}, k_{drb}, k_{xg}, \lambda, \tau, ...)\).

---
## 10. Habilidades (Resumo de Efeitos)
| Habilidade | Efeito Matemático (resumo) |
|-----------|------------------------------|
| VIS | \(p_{int} \leftarrow p_{int}(1 - k_{vis})\); incremento peso passes progressivos |
| PAS | Redução adicional de intercept curto: \(p_{int} \leftarrow p_{int}(1 - k_{pasShort})\) |
| DRB | \(p_{drb} \leftarrow p_{drb} + k_{drbAdd}\) + peso ação |
| FIN | \(p_{goal} \leftarrow p_{goal}(1 + k_{fin})\) (clamp) |
| WALL | defensores: \(p_{int} \leftarrow p_{int}(1 + k_{wall})\) |
| CAT | goleiro: \(p_{goal} \leftarrow p_{goal}(1 - k_{cat})\) |
| ENG | \(custo_{stamina} \leftarrow custo_{stamina}(1 - k_{eng})\) |
| CAP | amortecimento global (ex: pequena redução em variância: \(\tau \leftarrow \tau (1 - k_{cap})\)) |

---
## 11. Qualidade & Limitações Atuais
- xG ainda heurístico; não incorpora ângulo real nem tipo de assistência.
- Pressão agregada simples (inverse-distance média); futuro: kernel gaussiano e direção.
- Ausência de dependência espacial Y no modelo de finalização (apenas X).
- Ações longas e drible não incluem modelagem de aceleração temporal explícita (tempo abstraído).

---
## 12. Caminho de Evolução Imediato
1. Introduzir discretização formal de estado (sec. 8) em paralelo.
2. Migrar peso de ações para função utilidade \(U_a\) unificada.
3. Instrumentar logs com (stateId, U_a, P(a), nextStateId).
4. Calibrar \(\tau, \lambda, k_{prog}, k_{xg}\) contra divergência alvo.
5. Introduzir value iteration light para refinar risk/reward.

---
## 13. Síntese
O simulador evolui de um processo semi‑Markov de minutos (seleção de ataque + sequência) para um processo Markov granular onde cada micro decisão é uma amostra de uma distribuição de ações ponderadas por atributos, tática e contexto dinâmico (pressão, stamina, placar). Instrumentação detalhada permite estimação e ajuste de parâmetros via divergência estatística sobre métricas alvo de futebol realista.

---
## 14. Notação Rápida
| Símbolo | Significado |
|---------|-------------|
| \(R^{att,adj}_T\) | Rating ofensivo ajustado do time T |
| \(R^{def,adj}_T\) | Rating defensivo ajustado do time T |
| \(p_{int}\) | Probabilidade de interceptação de um passe |
| \(p_{drb}\) | Probabilidade de sucesso do drible |
| \(xG\) | Expected Goals de uma finalização |
| \(p_{goal}\) | Probabilidade efetiva de gol (após GK/skills) |
| \(pressure(p)\) | Escalar de pressão sofrida pelo portador |
| \(U_a\) | Utilidade crua de ação a em um estado |
| \(P(a|s)\) | Probabilidade de escolher ação a no estado s |

---
## 15. Referências Conceituais
- Cristopher M. Bishop, *Pattern Recognition and Machine Learning* – Softmax & energia.
- Spearman, W. (2020) – Modelos espaciais de futebol (inspiração xT / valor de estado).
- Sutton & Barto – *Reinforcement Learning* (estrutura MDP / value iteration).

> Fim do documento.
