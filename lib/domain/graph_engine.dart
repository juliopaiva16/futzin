/// Experimental graph-based match engine (Phase 1 stub).
/// For now it only provides coordinate layout helpers; no simulation logic.
import 'entities.dart';

/// Simple layout generator that assigns (x,y) normalized coordinates to players
/// based on formation, tactics width & lineHeight, and side (A left->right).
class GraphLayout {
  static void assignTeamCoordinates(TeamConfig team, {required bool leftToRight}) {
    final widthFactor = 0.5 + 0.5 * team.tactics.width; // 0.5..1
    final line = team.tactics.lineHeight; // 0..1

    // Collect per line
    final gk = team.selected.where((p) => p.pos == Position.GK).toList();
    final defs = team.selected.where((p) => p.pos == Position.DEF).toList();
    final mids = team.selected.where((p) => p.pos == Position.MID).toList();
    final fwds = team.selected.where((p) => p.pos == Position.FWD).toList();

    double yForIndex(int i, int count) {
      if (count <= 0) return 0.5;
      final raw = (i + 1) / (count + 1); // 0..1
      final center = 0.5;
      return center + (raw - center) * widthFactor;
    }

    // Base X anchors similar to painter logic
    final gkX = 0.05;
    final defX = 0.22 + 0.10 * line;
    final midCenterX = 0.50;
    final fwdX = 0.78 + 0.05 * line;

    void place(List<Player> players, double xFrac) {
      if (players.isEmpty) return;
      for (int i = 0; i < players.length; i++) {
        final p = players[i];
        final y = yForIndex(i, players.length);
        final xf = leftToRight ? xFrac : (1 - xFrac);
        p.x = xf;
        p.y = y;
      }
    }

    place(gk, gkX);
    place(defs, defX);

    // Midfield with optional split
    final split = team.formation.midRows;
    if (split != null && split.length == 2 && mids.isNotEmpty) {
      final r0 = split[0].clamp(0, mids.length);
      final r1 = split[1].clamp(0, mids.length - r0);
      final backRow = mids.take(r0).toList();
      final frontRow = mids.skip(r0).take(r1).toList();
      final midBackX = (midCenterX - 0.08) + 0.03 * line;
      final midFrontX = (midCenterX + 0.08) + 0.03 * line;
      place(backRow, midBackX);
      place(frontRow, midFrontX);
      final leftovers = mids.skip(r0 + r1).toList();
      place(leftovers, midCenterX);
    } else {
      place(mids, midCenterX);
    }

    place(fwds, fwdX);
  }

  /// Assign coordinates for both teams.
  static void assignMatchCoordinates(TeamConfig teamA, TeamConfig teamB) {
    assignTeamCoordinates(teamA, leftToRight: true);
    assignTeamCoordinates(teamB, leftToRight: false);
  }
}

/// Lightweight wrapper node (future: cache atributos efetivos etc.)
class PlayerNode {
  final Player p;
  PlayerNode(this.p);
  String get id => p.id;
  double get x => p.x ?? 0.5;
  double get y => p.y ?? 0.5;
  Position get pos => p.pos;
  Role get role => p.role;
  bool get isAvailable => !p.sentOff && !p.injured;
}

class MatchGraphView {
  final List<PlayerNode> teamANodes;
  final List<PlayerNode> teamBNodes;
  MatchGraphView(this.teamANodes, this.teamBNodes);

  static MatchGraphView build(TeamConfig a, TeamConfig b) {
    return MatchGraphView(
      a.selected.map(PlayerNode.new).toList(),
      b.selected.map(PlayerNode.new).toList(),
    );
  }
}

/// Placeholder class for future graph simulation engine.
class GraphMatchEngine {
  // Future: implement micro-tick loop and event stream.
  GraphMatchEngine();

  void prepare(TeamConfig a, TeamConfig b) {
    GraphLayout.assignMatchCoordinates(a, b);
    // Build nodes (unused for now)
    MatchGraphView.build(a, b);
  }
}
