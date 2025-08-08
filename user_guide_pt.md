# Futzin – Manual do Usuário

Simulador leve de futebol com táticas, formações, xG, momentum e log em tempo real.

- Plataformas: Android, iOS, Web, macOS, Windows, Linux (Flutter).
- Idiomas: Português e Inglês (auto de acordo com o idioma do dispositivo).

## 1) O que aparece na tela
- Barra superior: Placar, minuto, posse %, xG, botões para Compartilhar, Velocidade e Iniciar/Parar.
- Campo: Time A ataca da esquerda→direita (azul), Time B da direita→esquerda (vermelho). Jogadores exibem lesões (preenchimento laranja) e cartões (anel amarelo).
- Gráfico de momentum: Área por minuto (azul = Time A, vermelho = Time B) com marcadores de gols, chutes, cartões e lesões.
- Log de eventos: Descrição textual dos lances minuto a minuto.

## 2) Controles
- Iniciar partida: Roda uma simulação de 90 minutos.
- Parar: Interrompe a partida atual.
- Velocidade: 1x, 1.5x, 2x, 4x, 10x (aplicado instantaneamente).
- Compartilhar: Exporta o log completo, incluindo placar e xG.

## 3) Elencos, formações e substituições
- Escalação válida: 11 jogadores; exatamente 1 goleiro; DEF/MID/FWD conforme a formação escolhida.
- Formações disponíveis: 4-3-3, 4-4-2, 3-5-2, 5-3-2, 4-2-3-1 (meio dividido 2+3).
- Substituições: Até 5 por partida. Não é possível repor expulso; lesionados saem e devem ser trocados manualmente.
- Auto-escalar: Seleciona automaticamente os melhores por função.

## 4) Atributos e stamina
- Ataque: contribuição ofensiva (mais impacto em atacantes, depois meias e um pouco em zagueiros).
- Defesa: contribuição defensiva (mais impacto em zagueiros e goleiro, depois meias e um pouco em atacantes).
- Stamina: altera a efetividade dos atributos durante a partida.
  - Efetivo = base × (0,60 + 0,40 × stamina/100).
- Fadiga por minuto aumenta com Tempo e Pressão. Tempo/pressão altos cansam mais.

## 5) Táticas (prós e contras)
- Tendência Ofensiva (−1..+1): aumenta o ataque e reduz a defesa (moderado).
- Tempo (0..1): mais lances por minuto, mais passes rápidos, maior cansaço.
- Pressão (0..1): melhora a defesa pela pressão, aumenta o cansaço.
- Linha Defensiva (0..1): eleva levemente o ataque e reduz levemente a defesa; também move visualmente os jogadores para frente/atrás.
- Largura (0..1): eleva levemente o ataque e reduz levemente a defesa; espalha os jogadores verticalmente no campo.

## 6) Como cada minuto é simulado
- O minuto pode ser calmo ou conter um lance de ataque.
- Minuto calmo: posse ~50/50 e uma linha neutra no log.
- Com ataque: quem ataca é decidido pelo Ataque do time vs a Defesa do adversário.
- Sequência: acha espaço → 0–2 passes (com chance de interceptação) → falta (amarelo/vermelho; às vezes segundo amarelo) e lesão → chute.
- xG: 0,03–0,65 conforme ataque vs defesa; goleiro forte reduz chance de gol.
- Sem gol: vira “defesa do goleiro”, “desvio” ou “pra fora” no log.

## 7) Posse e momentum
- Posse: minutos calmos dão ~30s a cada time; minutos com ataque atribuem ~20–60s com ~65% para o atacante.
- Gráfico de momentum:
  - Área azul acima = Time A melhor; área vermelha abaixo = Time B melhor.
  - Marcadores: bola (gol), triângulo (chute), cartão (amarelo/vermelho), cruz laranja (lesão).
  - Áreas mais altas = mais pressão recente. Muitos triângulos sem bola sugerem goleiro bem ou finalização ruim.

## 8) Dicas de estratégia
- Azarão: leve viés defensivo, linha mais baixa, largura moderada, pressão moderada, tempo menor para reduzir volume de lances.
- Favorito: viés positivo, linha mais alta, largura maior, tempo alto, pressão média/alta. Observe stamina e cartões.
- Gestão: com tempo/pressão altos, planeje trocas no meio do 2º tempo. Substitua quem tem amarelo se o risco for grande.
- Formações:
  - 4-2-3-1: equilíbrio (dupla de volantes + 3 meias avançados).
  - 4-3-3: pressão no terço final com pontas.
  - 3-5-2: meio forte; 5-3-2: mais solidez defensiva.

## 9) Perguntas frequentes
- Por que partidas repetidas variam? O simulador é estocástico; sementes aleatórias mudam resultados.
- O que é xG? “Expected Goals” – chance de um chute virar gol.
- Por que não posso substituir expulso? Cartões vermelhos reduzem permanentemente os jogadores em campo.
- O app salva meus elencos? Sim, lineups e elencos são salvos localmente.
- Como resetar? Edite manualmente ou limpe o armazenamento local do app.

## 10) Limitações
- 90 minutos (sem prorrogação/pênaltis).
- Substituições manuais (até 5).

Bom jogo! Se curtir o Futzin, compartilhe suas partidas históricas.
