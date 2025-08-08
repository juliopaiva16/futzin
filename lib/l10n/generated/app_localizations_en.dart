// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FutSim Advanced';

  @override
  String get exportLog => 'Export log';

  @override
  String get startMatch => 'Start Match';

  @override
  String get stop => 'Stop';

  @override
  String get invalidLineups => 'Invalid lineups. Check GK/DEF/MID/FWD.';

  @override
  String get noEventsToExport => 'No events to export.';

  @override
  String get autoPick => 'Auto-pick';

  @override
  String subs(Object count) {
    return 'Subs ($count left)';
  }

  @override
  String get validLineup => 'Valid lineup';

  @override
  String get incompleteLineup => 'Incomplete lineup';

  @override
  String get teamName => 'Team name';

  @override
  String get formation => 'Formation';

  @override
  String get startButton => 'Start Match';

  @override
  String get possessionLabel => 'Possession';

  @override
  String get xgLabel => 'xG';

  @override
  String minuteShort(Object minute) {
    return 'Min $minute';
  }

  @override
  String get labelBias => 'Bias';

  @override
  String get labelTempo => 'Tempo';

  @override
  String get labelPressing => 'Pressing';

  @override
  String get labelLine => 'Def. line';

  @override
  String get labelWidth => 'Width';

  @override
  String get labelAutoSubs => 'Auto-subs';

  @override
  String get defensive => 'Defensive';

  @override
  String get offensive => 'Offensive';

  @override
  String get low => 'Low';

  @override
  String get high => 'High';

  @override
  String get narrow => 'Narrow';

  @override
  String get wide => 'Wide';

  @override
  String get edit => 'Edit';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get statusInjured => 'INJ';

  @override
  String get statusSentOff => 'OFF';

  @override
  String subsDialogTitle(Object left, Object team) {
    return 'Substitutions - $team ($left left)';
  }

  @override
  String get onField => 'On field';

  @override
  String get bench => 'Bench';

  @override
  String get confirm => 'Confirm';

  @override
  String get close => 'Close';

  @override
  String get kickoff => 'Kick-off!';

  @override
  String coolMinute(Object minute) {
    return '$minute\': calm minute in midfield.';
  }

  @override
  String goal(Object player, Object team) {
    return 'GOAL! $team scores with $player.';
  }

  @override
  String foulYellow(Object player, Object team) {
    return 'Strong foul. Yellow card for $player ($team).';
  }

  @override
  String foulRed(Object player, Object team) {
    return 'Horrible tackle! Red card for $player ($team).';
  }

  @override
  String secondYellow(Object player) {
    return 'Second yellow! $player is sent off.';
  }

  @override
  String injury(Object player, Object team) {
    return 'Injury! $player ($team) goes down hurt.';
  }

  @override
  String subTired(Object inn, Object out, Object team) {
    return 'Substitution $team: $out exhausted, $inn comes in.';
  }

  @override
  String subInjury(Object inn, Object out, Object team) {
    return 'Substitution $team: $out feels pain and leaves, $inn comes in.';
  }

  @override
  String subYellowRisk(Object inn, Object out, Object team) {
    return 'Substitution $team: $out (booked) out, $inn in.';
  }

  @override
  String get endMatch => 'Full time!';
}
