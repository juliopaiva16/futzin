import 'package:flutter_test/flutter_test.dart';
import 'package:futzin/domain/match_engine.dart';
import 'package:futzin/presentation/widgets/momentum_utils.dart';

void main() {
  test('computeMomentumSeries uses momentumDelta when provided', () {
    final events = <MatchEvent>[
      MatchEvent(10, 'Shot', 0, 0, 0.0, 0.0, kind: MatchEventKind.shot, side: 1, shotXg: 0.10, momentumDelta: 0.9),
      MatchEvent(10, 'Goal', 1, 0, 0.0, 0.0, kind: MatchEventKind.goal, side: 1, momentumDelta: 1.0),
    ];
    final series = computeMomentumSeries(events, 90);
    expect(series[10], closeTo(1.9, 1e-9));
  });

  test('computeMomentumSeries falls back to legacy mapping when delta missing', () {
    final events = <MatchEvent>[
      MatchEvent(5, 'Shot', 0, 0, 0.0, 0.0, kind: MatchEventKind.shot, side: -1, shotXg: 0.50),
    ];
    final series = computeMomentumSeries(events, 90);
    // Legacy mapping: side -1, base 0.5 + 0.7*0.5 = 0.85 → negative
    expect(series[5], lessThan(0));
  });
}
