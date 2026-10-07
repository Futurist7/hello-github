import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_recall/game/logic/scoring_engine.dart';
import 'package:spatial_recall/game/models/round_result.dart';
import 'package:spatial_recall/game/models/tile_position.dart';

ScoreBreakdown score(int correct, int target, {int seconds = 60, int streak = 0}) => ScoringEngine.score(
  correct: correct,
  target: target,
  recallTime: Duration(seconds: seconds),
  previousPerfectStreak: streak,
);

void main() {
  group('ScoringEngine', () {
    test('perfect round gets base + perfect bonus', () {
      final s = score(8, 8);
      expect(s.base, 800);
      expect(s.perfectBonus, 170);
      expect(s.speedBonus, 0); // Slow answer.
      expect(s.streakBonus, 0);
      expect(s.total, 970);
    });

    test('partial round: no perfect bonus', () {
      final s = score(6, 8);
      expect(s.base, 600);
      expect(s.perfectBonus, 0);
      expect(s.total, 600);
    });

    test('zero result scores zero', () {
      expect(score(0, 8, seconds: 0, streak: 5).total, 0);
    });

    test('faster answers earn a larger speed bonus', () {
      expect(score(8, 8, seconds: 2).speedBonus, greaterThan(score(8, 8, seconds: 8).speedBonus));
      expect(score(8, 8, seconds: 8).speedBonus, greaterThan(score(8, 8, seconds: 16).speedBonus));
      expect(score(8, 8, seconds: 2).speedBonus, lessThanOrEqualTo(200)); // ≤ 25% of base.
      expect(score(8, 8, seconds: 2).speed, SpeedRating.fast);
    });

    test('streak bonus follows consecutive perfect rounds and is capped', () {
      expect(score(8, 8, streak: 0).streakBonus, 0);
      expect(score(8, 8, streak: 1).streakBonus, 97);
      expect(score(8, 8, streak: 5).streakBonus, 485);
      expect(score(8, 8, streak: 50).streakBonus, score(8, 8, streak: 5).streakBonus);
      // Only perfect rounds earn it.
      expect(score(7, 8, streak: 4).streakBonus, 0);
    });

    test('stars and xp follow session accuracy bands', () {
      expect(ScoringEngine.stars(100), 5);
      expect(ScoringEngine.stars(92), 4);
      expect(ScoringEngine.stars(80), 3);
      expect(ScoringEngine.stars(79), 2);
      expect(ScoringEngine.stars(0), 0);
      expect(ScoringEngine.xpFor(100), 200);
      expect(ScoringEngine.xpFor(85), 150);
      expect(ScoringEngine.xpFor(60), 100);
      expect(ScoringEngine.xpFor(10), 50);
      expect(ScoringEngine.xpFor(100, rounds: 5), 100);
    });
  });

  test('accuracy is exact positions only', () {
    final e = RoundEvaluation(
      target: {for (var i = 0; i < 10; i++) TilePosition(i ~/ 5, i % 5)},
      selected: {
        for (var i = 0; i < 8; i++) TilePosition(i ~/ 5, i % 5),
        const TilePosition(3, 3), // Wrong.
        const TilePosition(2, 0), // Neighbour of (1,0): still wrong.
      },
      recallTime: Duration.zero,
    );
    expect(e.accuracy, 80);
    expect(e.wrong.length, 2);
    expect(e.missed.length, 2);
    expect(e.perfect, isFalse);
  });

  test('session accuracy pools all tiles across rounds', () {
    RoundEvaluation r(int correct, int target) => RoundEvaluation(
      target: {for (var i = 0; i < target; i++) TilePosition(0, i)},
      selected: {for (var i = 0; i < correct; i++) TilePosition(0, i)},
      recallTime: Duration.zero,
    );
    expect(sessionAccuracy([r(3, 3), r(1, 3), r(4, 4)]), 80);
    expect(sessionAccuracy([]), 0);
  });

  group('XpLevels', () {
    test('levels get progressively longer', () {
      expect(XpLevels.levelForXp(0), 1);
      expect(XpLevels.levelForXp(99), 1);
      expect(XpLevels.levelForXp(100), 2);
      expect(XpLevels.levelForXp(300), 3);
      expect(XpLevels.progress(350), (50, 300));
    });
  });
}
