import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_recall/game/logic/daily_challenge.dart';
import 'package:spatial_recall/game/logic/level_manager.dart';
import 'package:spatial_recall/game/logic/pattern_generator.dart';
import 'package:spatial_recall/game/logic/progression.dart';
import 'package:spatial_recall/game/logic/streak_manager.dart';
import 'package:spatial_recall/game/models/player_data.dart';
import 'package:spatial_recall/game/models/pattern.dart';
import 'package:spatial_recall/game/models/round_result.dart';
import 'package:spatial_recall/game/models/tile_position.dart';

SessionSpec levelSpec(int level) {
  final c = LevelManager.config(level);
  return SessionSpec(
    mode: RoundMode.level,
    config: c,
    patterns: [
      for (var i = 0; i < c.rounds; i++)
        generatePattern(gridSize: c.gridSize, tileCount: c.tileCount, seed: level * 100 + i),
    ],
  );
}

/// An answer to [pattern] with exactly [correct] right tiles (rest wrong).
RoundEvaluation answer(Pattern pattern, int correct, {Duration time = const Duration(seconds: 30)}) {
  final target = pattern.positions.toList();
  final wrong = <TilePosition>[];
  for (var r = 0; r < pattern.gridSize && wrong.length < target.length - correct; r++) {
    for (var c = 0; c < pattern.gridSize && wrong.length < target.length - correct; c++) {
      final t = TilePosition(r, c);
      if (!pattern.positions.contains(t)) wrong.add(t);
    }
  }
  return RoundEvaluation(target: pattern.positions, selected: {...target.take(correct), ...wrong}, recallTime: time);
}

/// Every round answered with [correctPerRound] correct tiles.
List<RoundEvaluation> session(SessionSpec spec, int correctPerRound) => [
  for (final p in spec.patterns) answer(p, correctPerRound.clamp(0, p.tileCount)),
];

void main() {
  final day = DateTime(2026, 10, 7, 14);

  group('progression', () {
    test('80% session accuracy promotes and unlocks the next level', () {
      final state = ProgressState.initial();
      expect(state.levels[1].unlocked, isFalse);
      final spec = levelSpec(2); // 4 tiles per round
      // 8 perfect rounds + 2 rounds at 2/4 = 36/40 = 90%.
      final rounds = [
        for (var i = 0; i < 8; i++) answer(spec.patterns[i], 4),
        answer(spec.patterns[8], 2),
        answer(spec.patterns[9], 2),
      ];
      state.levels[0].completed = true;
      state.levels[1].unlocked = true;
      final o = ProgressionEngine.apply(state, spec, rounds, day);
      expect(o.accuracy, 90);
      expect(o.promoted, isTrue);
      expect(o.unlockedLevel, 3);
      expect(o.perfectRounds, 8);
      expect(state.levels[1].completed, isTrue);
      expect(state.levels[2].unlocked, isTrue);
      expect(state.currentLevel, 3);
      expect(o.roundScores.length, 10);
      expect(o.score.total, o.roundScores.fold(0, (s, b) => s + b.total));
    });

    test('below 80% does not promote', () {
      final state = ProgressState.initial();
      final spec = levelSpec(1); // 3 tiles per round
      final o = ProgressionEngine.apply(state, spec, session(spec, 2), day); // 66%
      expect(o.promoted, isFalse);
      expect(o.unlockedLevel, isNull);
      expect(state.levels[1].unlocked, isFalse);
      expect(state.levels[0].completed, isFalse);
      expect(o.stars, 2);
    });

    test('streak bonus builds over consecutive perfect rounds within a session', () {
      final spec = levelSpec(1);
      final scores = ProgressionEngine.scoreRounds(session(spec, 3));
      expect(scores.first.streakBonus, 0);
      expect(scores[1].streakBonus, greaterThan(0));
      expect(scores[5].streakBonus, greaterThan(scores[1].streakBonus));
      expect(scores[9].streakBonus, scores[5].streakBonus); // Capped.
    });

    test('XP accumulates and player level rises', () {
      final state = ProgressState.initial();
      final spec = levelSpec(1);
      final o = ProgressionEngine.apply(state, spec, session(spec, 3), day);
      expect(o.xpGained, 200);
      expect(state.player.xp, 200);
      expect(state.player.xpLevel, 2);
      expect(o.leveledUp, isTrue);
    });

    test('best score and stars keep the best session', () {
      final state = ProgressState.initial();
      final spec = levelSpec(1);
      ProgressionEngine.apply(state, spec, session(spec, 3), day);
      final best = state.levels[0].bestScore;
      expect(state.levels[0].stars, 5);
      ProgressionEngine.apply(state, spec, session(spec, 1), day);
      expect(state.levels[0].bestScore, best);
      expect(state.levels[0].stars, 5);
      expect(state.levels[0].completed, isTrue);
      expect(state.player.bestScore, best);
    });

    test('stats: sessions played and running average accuracy', () {
      final state = ProgressState.initial();
      final spec = levelSpec(2); // 4 tiles
      ProgressionEngine.apply(state, spec, session(spec, 4), day);
      ProgressionEngine.apply(state, spec, session(spec, 2), day);
      expect(state.player.gamesPlayed, 2);
      expect(state.player.averageAccuracy, closeTo(75, 0.001));
    });

    test('only the first daily attempt is official', () {
      final state = ProgressState.initial();
      final daily = DailyChallenge.forDate(day);
      SessionSpec spec(bool official) => SessionSpec(
        mode: RoundMode.daily,
        config: daily.config,
        patterns: daily.patterns,
        dailyDate: daily.key,
        officialDaily: official,
      );
      final first = ProgressionEngine.apply(state, spec(true), session(spec(true), 3), day);
      expect(first.officialDailyRecorded, isTrue);
      expect(first.xpGained, lessThan(200)); // 5 rounds, worth half a level session.
      final score = state.dailyRecords[daily.key]!.score;
      // Even a mistaken "official" second attempt can't overwrite it.
      final second = ProgressionEngine.apply(state, spec(true), session(spec(true), 99), day);
      expect(second.officialDailyRecorded, isFalse);
      final practice = ProgressionEngine.apply(state, spec(false), session(spec(false), 99), day);
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
    test('same date gives the same patterns, regardless of time of day', () {
      final a = DailyChallenge.forDate(DateTime(2026, 10, 7, 0, 1));
      final b = DailyChallenge.forDate(DateTime(2026, 10, 7, 23, 59));
      expect(a.patterns.length, DailyChallenge.rounds);
      for (var i = 0; i < a.patterns.length; i++) {
        expect(a.patterns[i].positions, b.patterns[i].positions);
      }
      expect(a.patterns[0].positions, isNot(a.patterns[1].positions));
      expect(a.config.memoryMs, lessThanOrEqualTo(5000));
      expect(a.config.gridSize, b.config.gridSize);
      expect(a.key, '2026-10-07');
    });

    test('different dates give different patterns', () {
      final seen = <String>{};
      for (var i = 0; i < 60; i++) {
        final d = DailyChallenge.forDate(DateTime(2026, 1, 1).add(Duration(days: i)));
        final sorted = d.patterns.first.positions.toList()..sort();
        seen.add('${d.config.gridSize}:$sorted');
        expect(d.config.gridSize, inInclusiveRange(6, 7));
        expect(d.patterns.first.positions.length, d.config.tileCount);
      }
      expect(seen.length, 60);
    });
  });
}
