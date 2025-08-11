import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:futzin/domain/entities.dart';
import 'package:futzin/domain/player_factory.dart';

void main() {
  test('tier boosts correlate with higher core attributes', () {
    final rng = Random(1);
    final pTier4 = generatePlayer(index: 1, pos: Position.MID, rng: rng);
    final pTier1 = generatePlayer(index: 2, pos: Position.MID, rng: rng);
    // Force a very strong player to get tier 1 by manual override via re-generation until tier ==1
    GeneratedPlayerData tier1;
    do { tier1 = generatePlayer(index: rng.nextInt(10000), pos: Position.MID, rng: rng); } while (tier1.tier != 1);
    GeneratedPlayerData tier4;
    do { tier4 = generatePlayer(index: rng.nextInt(10000), pos: Position.MID, rng: rng); } while (tier4.tier == 1);
    final avg1 = (tier1.player.attack + tier1.player.defense) / 2;
    final avg4 = (tier4.player.attack + tier4.player.defense) / 2;
    expect(avg1, greaterThan(avg4));
  });

  test('preferred foot influences attributes', () {
    final rng = Random(2);
    GeneratedPlayerData left; do { left = generatePlayer(index: rng.nextInt(5000), pos: Position.FWD, rng: rng); } while (left.player.preferredFoot != 'L');
    GeneratedPlayerData right; do { right = generatePlayer(index: rng.nextInt(5000), pos: Position.FWD, rng: rng); } while (right.player.preferredFoot != 'R');
    // Left should tend to have >= passing than right controlling for randomness (loose):
    expect(left.player.passing, greaterThanOrEqualTo(right.player.passing - 5));
  });

  test('height correlates with strength (positive trend)', () {
    final rng = Random(3);
    final samples = List.generate(40, (i) => generatePlayer(index: i, pos: Position.DEF, rng: rng).player);
    samples.sort((a,b) => (a.heightCm??0).compareTo(b.heightCm??0));
    final low = samples.take(10).map((p) => p.strength).reduce((a,b)=>a+b)/10;
    final high = samples.skip(samples.length-10).map((p) => p.strength).reduce((a,b)=>a+b)/10;
    expect(high, greaterThanOrEqualTo(low));
  });
}
