import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/match_engine.dart';

/// Simple momentum chart: positive values (blue) favor Team A, negative (red) favor Team B.
class MomentumChart extends StatelessWidget {
  final List<MatchEvent> events;
  final int maxMinutes;
  final double height;
  const MomentumChart({
    super.key,
    required this.events,
    this.maxMinutes = 90,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _MomentumPainter(
          events: events,
          maxMinutes: maxMinutes,
          colorA: Colors.blueAccent,
          colorB: Colors.redAccent,
        ),
      ),
    );
  }
}

class _MomentumPainter extends CustomPainter {
  final List<MatchEvent> events;
  final int maxMinutes;
  final Color colorA;
  final Color colorB;
  _MomentumPainter({
    required this.events,
    required this.maxMinutes,
    required this.colorA,
    required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black.withValues(alpha: 0.04);
    canvas.drawRect(Offset.zero & size, bg);

    final axis = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axis);

    // Build per-minute weights and markers
    final minuteScores = List<double>.filled(maxMinutes + 1, 0.0); // 1..90
    final minuteMarkers = <int, List<MatchEvent>>{};

    for (final e in events) {
      final m = e.minute.clamp(1, maxMinutes).toInt();
      minuteMarkers.putIfAbsent(m, () => []).add(e);
      switch (e.kind) {
        case MatchEventKind.goal:
          minuteScores[m] += (e.side > 0 ? 1.0 : -1.0) * 1.0;
          break;
        case MatchEventKind.shot:
          final w = 0.5 + 0.7 * (e.shotXg ?? 0.10); // a bit stronger vertically
          minuteScores[m] += (e.side > 0 ? 1.0 : -1.0) * w;
          break;
        case MatchEventKind.card:
        case MatchEventKind.injury:
        case MatchEventKind.info:
          break;
      }
    }

    // Smoothing: keep higher alpha for more vertical variance
    final smooth = List<double>.filled(maxMinutes + 1, 0.0);
    for (int m = 1; m <= maxMinutes; m++) {
      final v = minuteScores[m].clamp(-2.0, 2.0).toDouble();
      smooth[m] = 0.70 * smooth[m - 1] + 0.30 * v;
    }

    // Draw filled areas with stronger vertical scale and dense horizontal sampling
    final scaleY = size.height * 0.46;
    final samplesPerMinute = 4; // denser horizontal curve
    final pathA = Path()..moveTo(0, midY);
    final pathB = Path()..moveTo(0, midY);

    for (int m = 1; m <= maxMinutes; m++) {
      for (int s = 0; s < samplesPerMinute; s++) {
        final t =
            (m - 1 + (s + 1) / samplesPerMinute) /
            maxMinutes; // 0..1 across width
        final x = size.width * t;
        // linear interp between m-1 and m
        final prev = smooth[max(0, m - 1)];
        final curr = smooth[m];
        final sv = prev + (curr - prev) * ((s + 1) / samplesPerMinute);
        final yPos = midY - max(0.0, sv) * scaleY;
        final yNeg = midY - min(0.0, sv) * scaleY;
        pathA.lineTo(x, yPos);
        pathB.lineTo(x, yNeg);
      }
    }
    pathA
      ..lineTo(size.width, midY)
      ..close();
    pathB
      ..lineTo(size.width, midY)
      ..close();

    canvas.drawPath(pathA, Paint()..color = colorA.withValues(alpha: 0.28));
    canvas.drawPath(pathB, Paint()..color = colorB.withValues(alpha: 0.28));

    // Event markers: stagger vertically and jitter X slightly to pack more per minute
    final rand = Random(0);
    for (final entry in minuteMarkers.entries) {
      final m = entry.key;
      int idxA = 0, idxB = 0, idxN = 0;
      for (final e in entry.value) {
        if (e.kind == MatchEventKind.info) continue;
        final baseX = size.width * (m / maxMinutes);
        final x = (baseX + (rand.nextDouble() - 0.5) * 6)
            .clamp(0.0, size.width)
            .toDouble();
        if (e.side == 0) {
          final y = midY - 2 - 6.0 * (idxN++);
          _drawNeutral(canvas, Offset(x, y));
          continue;
        }
        final isA = e.side > 0;
        double base = isA ? (midY - 10) : (midY + 10);
        double step = isA
            ? -9.0
            : 9.0; // tighter vertical spacing to allow more
        final offsetIndex = isA ? idxA++ : idxB++;
        final y = base + step * offsetIndex;
        switch (e.kind) {
          case MatchEventKind.goal:
            _drawBall(canvas, Offset(x, y), isA ? colorA : colorB);
            break;
          case MatchEventKind.card:
            _drawCard(
              canvas,
              Offset(x, y),
              e.cardColor == CardColor.red
                  ? Colors.red
                  : Colors.yellow.shade700,
            );
            break;
          case MatchEventKind.injury:
            _drawCross(canvas, Offset(x, y), Colors.orange);
            break;
          case MatchEventKind.shot:
            _drawTriangle(canvas, Offset(x, y), isA ? colorA : colorB);
            break;
          case MatchEventKind.info:
            break;
        }
      }
    }
  }

  void _drawNeutral(Canvas c, Offset o) {
    c.drawCircle(o, 2.5, Paint()..color = Colors.black45);
  }

  void _drawBall(Canvas c, Offset o, Color color) {
    final p = Paint()..color = color;
    c.drawCircle(o, 5, p);
    c.drawCircle(
      o,
      5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawCard(Canvas c, Offset o, Color color) {
    final r = Rect.fromCenter(center: o, width: 7, height: 9);
    c.drawRect(r, Paint()..color = color);
    c.drawRect(
      r,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawCross(Canvas c, Offset o, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    c.drawLine(o + const Offset(-4, -4), o + const Offset(4, 4), p);
    c.drawLine(o + const Offset(-4, 4), o + const Offset(4, -4), p);
  }

  void _drawTriangle(Canvas c, Offset o, Color color) {
    final path = Path()
      ..moveTo(o.dx, o.dy - 5)
      ..lineTo(o.dx - 5, o.dy + 5)
      ..lineTo(o.dx + 5, o.dy + 5)
      ..close();
    c.drawPath(path, Paint()..color = color.withValues(alpha: 0.9));
    c.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter oldDelegate) => true;
}
