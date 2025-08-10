import 'package:flutter_test/flutter_test.dart';
import 'package:futzin/domain/entities.dart';
import 'package:futzin/domain/match_engine.dart';
import 'package:futzin/domain/graph_public_helpers.dart';
import 'package:futzin/domain/messages.dart';

class _DummyMessages implements MatchMessages {
  @override String kickoff() => 'K';
  @override String endMatch() => 'E';
  // Unused in tests below (minimal implementation)
  @override String findsSpace(String p) => '$p finds space';
  @override String defenseCloses(String t) => 'def closes';
  @override String pass(String a, String b) => '$a -> $b';
  @override String intercepted(String d, String t) => 'intercept by $d';
  @override String shoots(String p) => '$p shoots';
  @override String goal(String t, String p) => 'goal';
  @override String savedByKeeper() => 'save';
  @override String deflectedOut() => 'deflect';
  @override String offTarget() => 'off';
  @override String lateFoul(String t) => 'foul';
  @override String foulRed(String p, String t) => 'red';
  @override String foulYellow(String p, String t) => 'yellow';
  @override String secondYellow(String p) => 'second';
  @override String injuryAfterChallenge(String p) => 'inj';
  @override String injuryOutside(String p, String t) => 'inj out';
  @override String dribble(String a, String b) => 'drb';
  @override String dribbleSuccess(String a) => 'drb ok';
  @override String dribbleFail(String a) => 'drb fail';
  @override String longPass(String a, String b) => 'long';
  @override String backPass(String a, String b) => 'back';
  @override String holdUp(String a) => 'hold';
  @override String launchForward(String a) => 'launch';
  // Additional interface methods
  @override String calmMinute(int minute) => 'calm';
  @override String recovery(String team, String player) => 'rec';
  @override String anticipates(String team) => 'ant';
  @override String foulOn(String player) => 'foul on';
  @override String foulRedBrutal(String player, String team) => 'brutal';
  @override String subTired(String team, String out, String inn) => 'sub tired';
  @override String subInjury(String team, String out, String inn) => 'sub injury';
  @override String subYellowRisk(String team, String out, String inn) => 'sub yellow';
}

void main() {
  test('multi-defender intercept probability increases with more defenders', () {
    final passer = Player(id:'p1', name:'P1', pos:Position.MID, attack:60, defense:50, stamina:70, pace:60, passing:60, technique:60, strength:60);
    final recv = Player(id:'p2', name:'P2', pos:Position.MID, attack:60, defense:50, stamina:70, pace:60, passing:60, technique:60, strength:60);
    passer.x = 0.3; passer.y = 0.5; recv.x = 0.7; recv.y = 0.5;
    List<Player> makeDefs(int n) {
      return List.generate(n, (i){
        final d = Player(id:'d$i', name:'D$i', pos:Position.DEF, attack:40, defense:60, stamina:70, pace:55, passing:40, technique:40, strength:60);
        // Place them near lane progressively
        d.x = 0.3 + (0.4 * (i+1)/(n+1)); d.y = 0.52 + (i%2==0?0.01:-0.01);
        return d;
      });
    }
    final p1 = graphMultiDefInterceptProb(passer, recv, makeDefs(1));
    final p2 = graphMultiDefInterceptProb(passer, recv, makeDefs(2));
    final p3 = graphMultiDefInterceptProb(passer, recv, makeDefs(3));
    expect(p2, greaterThanOrEqualTo(p1));
    expect(p3, greaterThanOrEqualTo(p2));
  });

  test('FIN ability increases pGoal relative', () {
    final fin = Player(id:'f1', name:'F1', pos:Position.FWD, attack:70, defense:30, stamina:80, pace:60, passing:50, technique:60, strength:55, abilityCodes:['FIN']);
    final base = Player(id:'b1', name:'B1', pos:Position.FWD, attack:70, defense:30, stamina:80, pace:60, passing:50, technique:60, strength:55);
    fin.x = base.x = 0.8; fin.y = base.y = 0.5;
    final teamA = TeamConfig(name:'A', formation:Formation.formations.first, tactics:Tactics(), squad:[fin, base]);
    final teamB = TeamConfig(name:'B', formation:Formation.formations.first, tactics:Tactics(), squad:[]);
    teamA.selectedIds..add(fin.id)..add(base.id);
    final messages = _DummyMessages();
    final eng = MatchEngine(teamA, teamB, messages: messages, seed: 1, useGraph: true);
  final atkR = PublicTeamRatings(attack:80, defense:70, gk:null);
  final defR = PublicTeamRatings(attack:60, defense:65, gk:null);
  final rFin = graphComputeShotModel(eng: eng, carrier: fin, atk: atkR, def: defR, attackingTeamA: true);
  final rBase = graphComputeShotModel(eng: eng, carrier: base, atk: atkR, def: defR, attackingTeamA: true);
    expect(rFin.pGoal, greaterThan(rBase.pGoal));
  });
}
