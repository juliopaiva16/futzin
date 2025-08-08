# Futzin – README para Desenvolvedores (PT)

Simulador de futebol em Flutter com formações, táticas, xG, momentum e mensagens localizadas.

- Tech: Flutter (Material 3), Dart. Plataformas: Android, iOS, Web, Desktop.
- i18n: ARB + gen-l10n (EN/PT). Saída não sintética em `lib/l10n/generated`.
- Arquitetura: camadas simples (domain, presentation, core).

## Estrutura do projeto
```
lib/
  app/
  core/
    localization/
  domain/
    entities.dart
    match_engine.dart
    messages.dart
  presentation/
    pages/home_page.dart
    widgets/
      pitch_widget.dart
      momentum_chart.dart
      team_config_widget.dart
l10n/
  app_en.arb, app_pt.arb
  l10n.yaml
```

## Conceitos principais
- MatchEngine: gera `MatchEvent` por minuto simulado.
  - Controle de velocidade via `setSpeed(multiplier)`; base ~450ms.
  - Eventos incluem metadados para visualização (`kind`, `side`, `shotXg`, `cardColor`).
  - Posse: minuto calmo ~30s cada; minuto com ataque ~20–60s com ~65% para o atacante.
- Ratings do time:
  - Ataque ≈ ATT FWD (1.0) + ATT MID (0.65) + ATT DEF (0.2), ajustado por táticas.
  - Defesa ≈ DEF DEF (1.0) + DEF MID (0.55) + DEF GK (1.2) + DEF FWD (0.1), ajustado por táticas e pressão.
  - Stamina reduz efetividade (60–100%). Fadiga depende de tempo/pressão.
- MomentumChart: suavização por minuto, áreas azul/vermelha, marcadores de gol, chute, cartão, lesão.
- PitchWidget: layout esquerda→direita vs direita→esquerda; suporte a meio dividido (ex.: 4-2-3-1 = [2,3]).

## Executando
- flutter pub get
- flutter run -d chrome|android|ios|macos|linux|windows
- flutter analyze; flutter test

## Localização
- `l10n.yaml`: `synthetic-package: false`, `output-dir: lib/l10n/generated`.
- Uso via `AppLocalizations.of(context)` e adaptador `_FlutterMatchMessages`.

## Dependências
- share_plus (SharePlus.instance.share(ShareParams(...)))
- shared_preferences
- flutter_localizations

## Notas de código
- Siga o analyzer; existem ignores para enums de posição (GK/DEF/MID/FWD).
- Engine determinística apenas com semente fixa.
- UI com CustomPainter para performance.

## Ideias de extensão
- Novas formações e sliders táticos (compactação, estilo de jogo).
- Substituições automáticas; prompts por fadiga/cartões.
- Prorrogação/pênaltis; modo torneio.
- Persistir velocidade; exportes mais ricos.

## Contribuição
- PRs bem-vindos. Formate com `dart format .`.
- Tests: unit para probabilidades e momentum.

## Licença
- MIT (sugerida) – adicione LICENSE se for distribuir.
