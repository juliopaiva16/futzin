import 'package:flutter/material.dart';

import '../../domain/entities.dart';

/// Simple pitch painter showing players by line.
class PitchWidget extends StatelessWidget {
  final TeamConfig teamA;
  final TeamConfig teamB;
  const PitchWidget({super.key, required this.teamA, required this.teamB});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PitchPainter(teamA: teamA, teamB: teamB),
      child: Container(),
    );
  }
}

class _PitchPainter extends CustomPainter {
  final TeamConfig teamA;
  final TeamConfig teamB;
  _PitchPainter({required this.teamA, required this.teamB});

  @override
  void paint(Canvas canvas, Size size) {
    final pitch = Paint()..color = const Color(0xFF2E7D32);
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Offset.zero & size, pitch);
    canvas.drawRect(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), line);
    canvas.drawLine(
      Offset(size.width / 2, 2),
      Offset(size.width / 2, size.height - 2),
      line,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 20, line);

    _drawTeam(canvas, size, teamA, leftToRight: true, color: Colors.blueAccent);
    _drawTeam(canvas, size, teamB, leftToRight: false, color: Colors.redAccent);
  }

  void _drawTeam(
    Canvas canvas,
    Size size,
    TeamConfig t, {
    required bool leftToRight,
    required Color color,
  }) {
    final gk = t.selected.where((p) => p.pos == Position.GK).toList();
    final defs = t.selected.where((p) => p.pos == Position.DEF).toList();
    final mids = t.selected.where((p) => p.pos == Position.MID).toList();
    final fwds = t.selected.where((p) => p.pos == Position.FWD).toList();

    // Distribute players vertically. "width" tactic controls how wide the team spreads.
    double yForIndex(int i, int count) {
      if (count <= 0) return size.height / 2;
      final raw = size.height * ((i + 1) / (count + 1));
      final center = size.height / 2;
      final spreadFactor =
          0.5 + 0.5 * t.tactics.width; // 0.5 (narrow) .. 1.0 (wide)
      return center + (raw - center) * spreadFactor;
    }

    // X positions per line (as a fraction of width).
    // Higher defensive line pushes DEF/FWD forward/back.
    final lineHeight = t.tactics.lineHeight; // 0..1
    final gkX = 0.08; // close to goal
    final defX = 0.25 + 0.10 * lineHeight; // push up with higher line
    final midCenterX = 0.50; // around center
    final fwdX =
        0.75 + 0.05 * lineHeight; // slightly closer to goal with higher line

    void drawLine(List<Player> players, double xFactor) {
      if (players.isEmpty) return;
      final x = size.width * (leftToRight ? xFactor : (1 - xFactor));
      for (int i = 0; i < players.length; i++) {
        final p = players[i];
        if (p.sentOff) continue;
        final y = yForIndex(i, players.length);
        final circle = Paint()
          ..color = p.injured ? Colors.orange : color
          ..style = PaintingStyle.fill;
        final border = Paint()
          ..color = p.yellowCards > 0 ? Colors.yellowAccent : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.yellowCards > 0 ? 3 : 1.5;

        canvas.drawCircle(Offset(x, y), 10, circle);
        canvas.drawCircle(Offset(x, y), 10, border);
      }
    }

    // Draw GK, DEF
    drawLine(gk, gkX);
    drawLine(defs, defX);

    // Draw MID: support split rows like 4-2-3-1 (2 + 3)
    final split = t.formation.midRows;
    if (split != null && split.length == 2 && mids.isNotEmpty) {
      final r0 = split[0].clamp(0, mids.length);
      final r1 = (split[1]).clamp(0, mids.length - r0);
      final backRow = mids.take(r0).toList();
      final frontRow = mids.skip(r0).take(r1).toList();

      // Back midfielders slightly behind center, front slightly ahead
      final midBackX = (midCenterX - 0.08) + 0.03 * lineHeight;
      final midFrontX = (midCenterX + 0.08) + 0.03 * lineHeight;
      drawLine(backRow, midBackX);
      drawLine(frontRow, midFrontX);
      // If there are leftover mids (mismatch), draw them at center
      final leftovers = mids.skip(r0 + r1).toList();
      if (leftovers.isNotEmpty) drawLine(leftovers, midCenterX);
    } else {
      // Single midfield line
      drawLine(mids, midCenterX);
    }

    // Draw FWD
    drawLine(fwds, fwdX);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => true;
}
