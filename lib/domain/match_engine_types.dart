part of 'match_engine.dart';

enum MatchEventKind { info, shot, goal, card, injury }

enum CardColor { yellow, red }

enum _SeqType { text, shot, goal, card, injury }

enum _CardType { yellow, red }

class MatchEvent {
  final int minute;
  final String text;
  final int scoreA;
  final int scoreB;
  final double xgA;
  final double xgB;
  final MatchEventKind kind;
  final int side; // +1 A, -1 B, 0 neutral
  final double? shotXg;
  final CardColor? cardColor;
  MatchEvent(this.minute, this.text, this.scoreA, this.scoreB, this.xgA, this.xgB,
      {this.kind = MatchEventKind.info, this.side = 0, this.shotXg, this.cardColor});
}

class _TeamRatings {
  final double attackAdj;
  final double defenseAdj;
  final Player? gk;
  _TeamRatings({required this.attackAdj, required this.defenseAdj, required this.gk});
}

class _SeqEvent {
  final _SeqType type;
  final String text;
  final double? xg; // for shots/goals
  final Player? offender;
  final _CardType? cardType;
  final Player? injuredPlayer;
  _SeqEvent._(this.type, this.text, {this.xg, this.offender, this.cardType, this.injuredPlayer});
  factory _SeqEvent.text(String t) => _SeqEvent._(_SeqType.text, t);
  factory _SeqEvent.shot(double xg, String t) => _SeqEvent._(_SeqType.shot, t, xg: xg);
  factory _SeqEvent.goal(String t, double xg) => _SeqEvent._(_SeqType.goal, t, xg: xg);
  factory _SeqEvent.card(String t, Player p, _CardType c) => _SeqEvent._(_SeqType.card, t, offender: p, cardType: c);
  factory _SeqEvent.injury(String t, Player p) => _SeqEvent._(_SeqType.injury, t, injuredPlayer: p);
}
