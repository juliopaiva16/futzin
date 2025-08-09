/// Abstraction for localizing match log messages.
///
/// The domain layer depends on this interface only. UI provides an
/// implementation (e.g. using Flutter gen-l10n) and injects it into the
/// [MatchEngine].
abstract class MatchMessages {
  String kickoff();
  String calmMinute(int minute);

  String recovery(String team, String player);
  String foulOn(String player);
  String anticipates(String team);

  String pass(String from, String to);
  String intercepted(String interceptor, String team);
  String injuryAfterChallenge(String player);

  String findsSpace(String player);
  String defenseCloses(String team);
  String shoots(String player);

  String goal(String team, String player);
  String savedByKeeper();
  String deflectedOut();
  String offTarget();

  String foulYellow(String player, String team);
  String foulRed(String player, String team);
  String foulRedBrutal(String player, String team);
  String lateFoul(String team);

  String injuryOutside(String player, String team);

  String subTired(String team, String out, String inn);
  String subInjury(String team, String out, String inn);
  String subYellowRisk(String team, String out, String inn);

  String secondYellow(String player);
  String endMatch();

  String dribble(String player, String defender); // player attempts dribble vs defender
  String dribbleSuccess(String player); // successful dribble
  String dribbleFail(String player); // failed dribble lost ball
  String longPass(String from, String to); // attempted longer pass
  String backPass(String from, String to); // safety/backwards pass
  String holdUp(String player); // player holds the ball
  String launchForward(String from); // long launch forward (50/50)
}
