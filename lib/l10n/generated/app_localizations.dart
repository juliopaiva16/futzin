import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FutSim Advanced'**
  String get appTitle;

  /// No description provided for @exportLog.
  ///
  /// In en, this message translates to:
  /// **'Export log'**
  String get exportLog;

  /// No description provided for @startMatch.
  ///
  /// In en, this message translates to:
  /// **'Start Match'**
  String get startMatch;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @invalidLineups.
  ///
  /// In en, this message translates to:
  /// **'Invalid lineups. Check GK/DEF/MID/FWD.'**
  String get invalidLineups;

  /// No description provided for @noEventsToExport.
  ///
  /// In en, this message translates to:
  /// **'No events to export.'**
  String get noEventsToExport;

  /// No description provided for @autoPick.
  ///
  /// In en, this message translates to:
  /// **'Auto-pick'**
  String get autoPick;

  /// No description provided for @subs.
  ///
  /// In en, this message translates to:
  /// **'Subs ({count} left)'**
  String subs(Object count);

  /// No description provided for @validLineup.
  ///
  /// In en, this message translates to:
  /// **'Valid lineup'**
  String get validLineup;

  /// No description provided for @incompleteLineup.
  ///
  /// In en, this message translates to:
  /// **'Incomplete lineup'**
  String get incompleteLineup;

  /// No description provided for @teamName.
  ///
  /// In en, this message translates to:
  /// **'Team name'**
  String get teamName;

  /// No description provided for @formation.
  ///
  /// In en, this message translates to:
  /// **'Formation'**
  String get formation;

  /// No description provided for @startButton.
  ///
  /// In en, this message translates to:
  /// **'Start Match'**
  String get startButton;

  /// No description provided for @possessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Possession'**
  String get possessionLabel;

  /// No description provided for @xgLabel.
  ///
  /// In en, this message translates to:
  /// **'xG'**
  String get xgLabel;

  /// No description provided for @minuteShort.
  ///
  /// In en, this message translates to:
  /// **'Min {minute}'**
  String minuteShort(Object minute);

  /// No description provided for @labelBias.
  ///
  /// In en, this message translates to:
  /// **'Bias'**
  String get labelBias;

  /// No description provided for @labelTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get labelTempo;

  /// No description provided for @labelPressing.
  ///
  /// In en, this message translates to:
  /// **'Pressing'**
  String get labelPressing;

  /// No description provided for @labelLine.
  ///
  /// In en, this message translates to:
  /// **'Def. line'**
  String get labelLine;

  /// No description provided for @labelWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get labelWidth;

  /// No description provided for @labelAutoSubs.
  ///
  /// In en, this message translates to:
  /// **'Auto-subs'**
  String get labelAutoSubs;

  /// No description provided for @defensive.
  ///
  /// In en, this message translates to:
  /// **'Defensive'**
  String get defensive;

  /// No description provided for @offensive.
  ///
  /// In en, this message translates to:
  /// **'Offensive'**
  String get offensive;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @narrow.
  ///
  /// In en, this message translates to:
  /// **'Narrow'**
  String get narrow;

  /// No description provided for @wide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get wide;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @statusInjured.
  ///
  /// In en, this message translates to:
  /// **'INJ'**
  String get statusInjured;

  /// No description provided for @statusSentOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get statusSentOff;

  /// No description provided for @subsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Substitutions - {team} ({left} left)'**
  String subsDialogTitle(Object left, Object team);

  /// No description provided for @onField.
  ///
  /// In en, this message translates to:
  /// **'On field'**
  String get onField;

  /// No description provided for @bench.
  ///
  /// In en, this message translates to:
  /// **'Bench'**
  String get bench;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @kickoff.
  ///
  /// In en, this message translates to:
  /// **'Kick-off!'**
  String get kickoff;

  /// No description provided for @coolMinute.
  ///
  /// In en, this message translates to:
  /// **'{minute}\': calm minute in midfield.'**
  String coolMinute(Object minute);

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'GOAL! {team} scores with {player}.'**
  String goal(Object player, Object team);

  /// No description provided for @foulYellow.
  ///
  /// In en, this message translates to:
  /// **'Strong foul. Yellow card for {player} ({team}).'**
  String foulYellow(Object player, Object team);

  /// No description provided for @foulRed.
  ///
  /// In en, this message translates to:
  /// **'Horrible tackle! Red card for {player} ({team}).'**
  String foulRed(Object player, Object team);

  /// No description provided for @secondYellow.
  ///
  /// In en, this message translates to:
  /// **'Second yellow! {player} is sent off.'**
  String secondYellow(Object player);

  /// No description provided for @injury.
  ///
  /// In en, this message translates to:
  /// **'Injury! {player} ({team}) goes down hurt.'**
  String injury(Object player, Object team);

  /// No description provided for @subTired.
  ///
  /// In en, this message translates to:
  /// **'Substitution {team}: {out} exhausted, {inn} comes in.'**
  String subTired(Object inn, Object out, Object team);

  /// No description provided for @subInjury.
  ///
  /// In en, this message translates to:
  /// **'Substitution {team}: {out} feels pain and leaves, {inn} comes in.'**
  String subInjury(Object inn, Object out, Object team);

  /// No description provided for @subYellowRisk.
  ///
  /// In en, this message translates to:
  /// **'Substitution {team}: {out} (booked) out, {inn} in.'**
  String subYellowRisk(Object inn, Object out, Object team);

  /// No description provided for @endMatch.
  ///
  /// In en, this message translates to:
  /// **'Full time!'**
  String get endMatch;

  /// No description provided for @hubTitle.
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get hubTitle;

  /// No description provided for @navPlayerMarket.
  ///
  /// In en, this message translates to:
  /// **'Player Market'**
  String get navPlayerMarket;

  /// No description provided for @navTeamManagement.
  ///
  /// In en, this message translates to:
  /// **'Team Management'**
  String get navTeamManagement;

  /// No description provided for @navGoToMatch.
  ///
  /// In en, this message translates to:
  /// **'Go to Match'**
  String get navGoToMatch;

  /// No description provided for @marketTitle.
  ///
  /// In en, this message translates to:
  /// **'Player Market'**
  String get marketTitle;

  /// No description provided for @filterPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get filterPosition;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @hire.
  ///
  /// In en, this message translates to:
  /// **'Hire'**
  String get hire;

  /// No description provided for @teamManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Team Management'**
  String get teamManagementTitle;

  /// No description provided for @subOut.
  ///
  /// In en, this message translates to:
  /// **'OUT'**
  String get subOut;

  /// No description provided for @subIn.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get subIn;

  /// No description provided for @noAbilities.
  ///
  /// In en, this message translates to:
  /// **'No abilities'**
  String get noAbilities;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
