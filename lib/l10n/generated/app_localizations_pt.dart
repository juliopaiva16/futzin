// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'FutSim Avançado';

  @override
  String get exportLog => 'Exportar log';

  @override
  String get startMatch => 'Iniciar Partida';

  @override
  String get stop => 'Parar';

  @override
  String get invalidLineups =>
      'Escalações inválidas. Verifique GOL/DEF/MEI/ATA.';

  @override
  String get noEventsToExport => 'Sem eventos para exportar.';

  @override
  String get autoPick => 'Autoescalar';

  @override
  String subs(Object count) {
    return 'Subs ($count rest.)';
  }

  @override
  String get validLineup => 'Escalação válida';

  @override
  String get incompleteLineup => 'Escalação incompleta';

  @override
  String get teamName => 'Nome do time';

  @override
  String get formation => 'Formação';

  @override
  String get startButton => 'Iniciar Partida';

  @override
  String get possessionLabel => 'Posse';

  @override
  String get xgLabel => 'xG';

  @override
  String minuteShort(Object minute) {
    return 'Min $minute';
  }

  @override
  String get labelBias => 'Viés';

  @override
  String get labelTempo => 'Ritmo';

  @override
  String get labelPressing => 'Pressão';

  @override
  String get labelLine => 'Linha def.';

  @override
  String get labelWidth => 'Largura';

  @override
  String get labelAutoSubs => 'Auto-subs';

  @override
  String get defensive => 'Defensivo';

  @override
  String get offensive => 'Ofensivo';

  @override
  String get low => 'Baixo';

  @override
  String get high => 'Alto';

  @override
  String get narrow => 'Estreito';

  @override
  String get wide => 'Aberto';

  @override
  String get edit => 'Editar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Salvar';

  @override
  String get statusInjured => 'LES';

  @override
  String get statusSentOff => 'EXP';

  @override
  String subsDialogTitle(Object left, Object team) {
    return 'Substituições - $team ($left restantes)';
  }

  @override
  String get onField => 'Em campo';

  @override
  String get bench => 'Banco';

  @override
  String get confirm => 'Confirmar';

  @override
  String get close => 'Fechar';

  @override
  String get kickoff => 'Início de jogo!';

  @override
  String coolMinute(Object minute) {
    return '$minute\': jogo cadenciado no meio-campo.';
  }

  @override
  String goal(Object player, Object team) {
    return 'GOOOOOOL! $team marca com $player.';
  }

  @override
  String foulYellow(Object player, Object team) {
    return 'Falta forte. Cartão amarelo para $player ($team).';
  }

  @override
  String foulRed(Object player, Object team) {
    return 'Entrada duríssima! Cartão vermelho para $player ($team).';
  }

  @override
  String secondYellow(Object player) {
    return 'Segundo amarelo! $player está expulso.';
  }

  @override
  String injury(Object player, Object team) {
    return 'Lesão! $player ($team) cai sentindo.';
  }

  @override
  String subTired(Object inn, Object out, Object team) {
    return 'Substituição $team: $out exausto, entra $inn.';
  }

  @override
  String subInjury(Object inn, Object out, Object team) {
    return 'Substituição $team: $out sente e sai, entra $inn.';
  }

  @override
  String subYellowRisk(Object inn, Object out, Object team) {
    return 'Substituição $team: $out (amarelado) dá lugar a $inn.';
  }

  @override
  String get endMatch => 'Fim de jogo!';
}
