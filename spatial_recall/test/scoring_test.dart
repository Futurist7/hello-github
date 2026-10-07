import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_recall/game/logic/scoring_engine.dart';
import 'package:spatial_recall/game/models/round_result.dart';
import 'package:spatial_recall/game/models/tile_position.dart';

void main() {
  group('ScoringEngine', () {
    test('perfect result gets base + perfect bonus', () {
      final s = ScoringEngine.score(
        correct: 8,
        target: 8,
        recallTime: const Duration(seconds: 60),
        previousSuccessStreak: 0,
      );
      expect(s.base, 800);
      expect(s.perfectBonus, 300);
      expect(s.speedBonus, 0); // Slow answer.
      expect(s.streakBonus, 0);
      expect(s.total, 1100);
    });

    test('partial result: no perfect bonus', () {
      final s = ScoringEngine.score(
        correct: 6,
        target: 8,
        recallTime: const Duration(seconds: 60),
        previousSuccessStreak: 0,
      );
      expect(s.base, 600);
      expect(s.perfectBonus, 0);
      expect(s.total, 600);
    });

    test('zero result scores zero', () {
      final s = ScoringEngine.score(correct: 0, target: 8, recallTime: Duration.zero, previousSuccessStreak: 5);
      expect(s.total, 0);
    });

    test('faster answers earn a larger speed bonus', () {
      int bonus(int seconds) => ScoringEngine.score(
        correct: 8,
        target: 8,
        recallTime: Duration(seconds: seconds),
        previousSuccessStreak: 0,
      ).speedBonus;
      expect(bonus(2), greaterThan(bonus(8)));
      expect(bonus(8), greaterThan(bonus(16)));
      expect(bonus(2), lessThanOrEqualTo(200)); // ≤ 25% of base.
      expect(
        ScoringEngine.score(
          correct: 8,
          target: 8,
          recallTime: const Duration(seconds: 2),
          previousSuccessStreak: 0,
        ).speed,
        SpeedRating.fast,
      );
    });

    test('streak bonus grows and is capped', () {
      int streak(int prev) => ScoringEngine.score(
        correct: 8,
        target: 8,
        recallTime: const Duration(seconds: 60),
        previousSuccessStreak: prev,
      ).streakBonus;
      expect(streak(0), 0);
      expect(streak(1), 110);
      expect(streak(5), 550);
      expect(streak(50), streak(5));
    });

    test('no streak bonus on a weak round', () {
      final s = ScoringEngine.score(
        correct: 2,
        target: 8,
        recallTime: const Duration(seconds: 60),
        previousSuccessStreak: 4,
      );
      expect(s.streakBonus, 0);
    });

    test('stars and xp follow accuracy bands', () {
      expect(ScoringEngine.stars(100), 5);
      expect(ScoringEngine.stars(75), 4);
      expect(ScoringEngine.stars(60), 3);
      expect(ScoringEngine.stars(0), 0);
      expect(ScoringEngine.xpFor(100), 100);
      expect(ScoringEngine.xpFor(85), 75);
      expect(ScoringEngine.xpFor(60), 50);
      expect(ScoringEngine.xpFor(10), 25);
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
