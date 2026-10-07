import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_recall/game/logic/daily_challenge.dart';
import 'package:spatial_recall/game/logic/level_manager.dart';
import 'package:spatial_recall/game/logic/pattern_generator.dart';
import 'package:spatial_recall/game/logic/progression.dart';
import 'package:spatial_recall/game/logic/streak_manager.dart';
import 'package:spatial_recall/game/models/player_data.dart';
import 'package:spatial_recall/game/models/round_result.dart';
import 'package:spatial_recall/game/models/tile_position.dart';

RoundSpec levelSpec(int level) {
  final c = LevelManager.config(level);
  return RoundSpec(
    mode: RoundMode.level,
    config: c,
    pattern: generatePattern(gridSize: c.gridSize, tileCount: c.tileCount, seed: level),
  );
}

/// An answer with exactly [correct] right tiles (rest wrong).
RoundEvaluation answer(RoundSpec spec, int correct) {
  final target = spec.pattern.positions.toList();
  final wrong = <TilePosition>[];
  for (var r = 0; r < spec.config.gridSize && wrong.length < target.length - correct; r++) {
    for (var c = 0; c < spec.config.gridSize && wrong.length < target.length - correct; c++) {
      final t = TilePosition(r, c);
      if (!spec.pattern.positions.contains(t)) wrong.add(t);
    }
  }
  return RoundEvaluation(
    target: spec.pattern.positions,
    selected: {...target.take(correct), ...wrong},
    recallTime: const Duration(seconds: 30),
  );
}

void main() {
  final day = DateTime(2026, 10, 7, 14);

  group('progression', () {
    test('passing a level completes it and unlocks the next', () {
      final state = ProgressState.initial();
      expect(state.levels[1].unlocked, isFalse);
      final spec = levelSpec(1);
      final o = ProgressionEngine.apply(state, answer(spec, 3), spec, day);
      expect(o.passed, isTrue);
      expect(o.unlockedLevel, 2);
      expect(state.levels[0].completed, isTrue);
      expect(state.levels[1].unlocked, isTrue);
      expect(state.currentLevel, 2);
    });

    test('failing does not unlock the next level', () {
      final state = ProgressState.initial();
      final spec = levelSpec(1);
      final o = ProgressionEngine.apply(state, answer(spec, 1), spec, day);
      expect(o.passed, isFalse);
      expect(o.unlockedLevel, isNull);
      expect(state.levels[1].unlocked, isFalse);
      expect(state.levels[0].completed, isFalse);
    });

    test('XP accumulates and player level rises', () {
      final state = ProgressState.initial();
      final spec = levelSpec(1);
      final o = ProgressionEngine.apply(state, answer(spec, 3), spec, day);
      expect(o.xpGained, 100);
      expect(state.player.xp, 100);
      expect(state.player.xpLevel, 2);
      expect(o.leveledUp, isTrue);
    });

    test('best score and stars keep the best result', () {
      final state = ProgressState.initial();
      final spec = levelSpec(2);
      ProgressionEngine.apply(state, answer(spec, 4), spec, day);
      final best = state.levels[1].bestScore;
      expect(state.levels[1].stars, 5);
      ProgressionEngine.apply(state, answer(spec, 2), spec, day);
      expect(state.levels[1].bestScore, best);
      expect(state.levels[1].stars, 5);
      expect(state.player.bestScore, greaterThanOrEqualTo(best));
    });

    test('stats: games played and running average accuracy', () {
      final state = ProgressState.initial();
      final spec = levelSpec(2); // 4 tiles
      ProgressionEngine.apply(state, answer(spec, 4), spec, day);
      ProgressionEngine.apply(state, answer(spec, 2), spec, day);
      expect(state.player.gamesPlayed, 2);
      expect(state.player.averageAccuracy, closeTo(75, 0.001));
    });

    test('only the first daily attempt is official', () {
      final state = ProgressState.initial();
      final daily = DailyChallenge.forDate(day);
      RoundSpec spec(bool official) => RoundSpec(
        mode: RoundMode.daily,
        config: daily.config,
        pattern: daily.pattern,
        dailyDate: daily.key,
        officialDaily: official,
      );
      final first = ProgressionEngine.apply(state, answer(spec(true), 5), spec(true), day);
      expect(first.officialDailyRecorded, isTrue);
      final score = state.dailyRecords[daily.key]!.score;
      // Even a mistaken "official" second attempt can't overwrite it.
      final second = ProgressionEngine.apply(state, answer(spec(true), daily.config.tileCount), spec(true), day);
      expect(second.officialDailyRecorded, isFalse);
      final practice = ProgressionEngine.apply(state, answer(spec(false), daily.config.tileCount), spec(false), day);
      expect(practice.officialDailyRecorded, isFalse);
      expect(state.dailyRecords[daily.key]!.score, score);
    });
  });

  group('streak', () {
    test('same day keeps the streak', () {
      final p = PlayerData();
      StreakManager.recordPlay(p, DateTime(2026, 10, 7, 9));
      StreakManager.recordPlay(p, DateTime(2026, 10, 7, 23, 59));
      expect(p.currentStreak, 1);
    });

    test('consecutive days increase it, across month boundaries', () {
      final p = PlayerData();
      StreakManager.recordPlay(p, DateTime(2026, 10, 30, 22));
      StreakManager.recordPlay(p, DateTime(2026, 10, 31, 1));
      StreakManager.recordPlay(p, DateTime(2026, 11, 1, 8));
      expect(p.currentStreak, 3);
      expect(p.longestStreak, 3);
      expect(StreakManager.effectiveStreak(p, DateTime(2026, 11, 2)), 3);
    });

    test('a missed day resets it but keeps the longest', () {
      final p = PlayerData();
      StreakManager.recordPlay(p, DateTime(2026, 10, 5));
      StreakManager.recordPlay(p, DateTime(2026, 10, 6));
      expect(StreakManager.effectiveStreak(p, DateTime(2026, 10, 8)), 0);
      StreakManager.recordPlay(p, DateTime(2026, 10, 8));
      expect(p.currentStreak, 1);
      expect(p.longestStreak, 2);
    });

    test('handles DST transitions', () {
      final p = PlayerData();
      StreakManager.recordPlay(p, DateTime(2026, 3, 28, 23));
      StreakManager.recordPlay(p, DateTime(2026, 3, 29, 23));
      StreakManager.recordPlay(p, DateTime(2026, 3, 30, 0, 30));
      expect(p.currentStreak, 3);
    });

    test('clock going backwards does not break the streak', () {
      final p = PlayerData();
      StreakManager.recordPlay(p, DateTime(2026, 10, 7));
      StreakManager.recordPlay(p, DateTime(2026, 10, 5));
      expect(p.currentStreak, 1);
      expect(p.lastPlayedDate, DateTime(2026, 10, 7));
    });
  });

  group('daily challenge', () {
    test('same date gives the same pattern, regardless of time of day', () {
      final a = DailyChallenge.forDate(DateTime(2026, 10, 7, 0, 1));
      final b = DailyChallenge.forDate(DateTime(2026, 10, 7, 23, 59));
      expect(a.pattern.positions, b.pattern.positions);
      expect(a.config.gridSize, b.config.gridSize);
      expect(a.key, '2026-10-07');
    });

    test('different dates give different patterns', () {
      final seen = <String>{};
      for (var i = 0; i < 60; i++) {
        final d = DailyChallenge.forDate(DateTime(2026, 1, 1).add(Duration(days: i)));
        final sorted = d.pattern.positions.toList()..sort();
        seen.add('${d.config.gridSize}:$sorted');
        expect(d.config.gridSize, inInclusiveRange(6, 7));
        expect(d.pattern.positions.length, d.config.tileCount);
      }
      expect(seen.length, 60);
    });
  });
}
