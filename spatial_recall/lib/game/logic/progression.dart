import '../models/player_data.dart';
import '../models/round_result.dart';
import 'level_manager.dart';
import 'scoring_engine.dart';
import 'streak_manager.dart';

/// All persistent progression state, as one value the engine can update.
class ProgressState {
  ProgressState({required this.player, required this.levels, required this.dailyRecords});

  final PlayerData player;

  /// Index 0 is level 1.
  final List<LevelProgress> levels;

  /// Official daily results keyed by `yyyy-mm-dd`.
  final Map<String, DailyRecord> dailyRecords;

  factory ProgressState.initial() => ProgressState(
    player: PlayerData(),
    levels: [for (var i = 0; i < LevelManager.levelCount; i++) LevelProgress(unlocked: i == 0)],
    dailyRecords: {},
  );

  int get levelsCompleted => levels.where((l) => l.completed).length;

  /// The level the player should play next.
  int get currentLevel {
    for (var i = 0; i < levels.length; i++) {
      if (levels[i].unlocked && !levels[i].completed) return i + 1;
    }
    var last = 1;
    for (var i = 0; i < levels.length; i++) {
      if (levels[i].unlocked) last = i + 1;
    }
    return last;
  }

  bool get allLevelsCompleted => levels.every((l) => l.completed);

  int get bestDailyScore => dailyRecords.values.fold(0, (best, r) => r.score > best ? r.score : best);
}

/// Applies a finished round to the player's progression.
class ProgressionEngine {
  static RoundOutcome apply(ProgressState state, RoundEvaluation eval, RoundSpec spec, DateTime now) {
    final player = state.player;
    final accuracy = eval.accuracy;
    final passed = accuracy >= spec.config.passPercentage;

    final score = ScoringEngine.score(
      correct: eval.correctCount,
      target: eval.targetCount,
      recallTime: eval.recallTime,
      previousSuccessStreak: player.successStreak,
    );
    final stars = ScoringEngine.stars(accuracy);
    final xpGained = ScoringEngine.xpFor(accuracy);

    final xpBefore = player.xp;
    final levelBefore = XpLevels.levelForXp(xpBefore);
    final newBest = score.total > player.bestScore;

    player.xp += xpGained;
    player.xpLevel = XpLevels.levelForXp(player.xp);
    player.averageAccuracy = (player.averageAccuracy * player.gamesPlayed + accuracy) / (player.gamesPlayed + 1);
    player.gamesPlayed += 1;
    player.totalScore += score.total;
    if (newBest) player.bestScore = score.total;
    player.successStreak = passed ? player.successStreak + 1 : 0;
    StreakManager.recordPlay(player, now);

    int? unlocked;
    var dailyRecorded = false;
    if (spec.mode == RoundMode.level) {
      final idx = spec.config.level - 1;
      final progress = state.levels[idx];
      progress.unlocked = true;
      if (score.total > progress.bestScore) progress.bestScore = score.total;
      if (accuracy > progress.bestAccuracy) progress.bestAccuracy = accuracy;
      if (stars > progress.stars) progress.stars = stars;
      if (passed) {
        progress.completed = true;
        if (idx + 1 < state.levels.length && !state.levels[idx + 1].unlocked) {
          state.levels[idx + 1].unlocked = true;
          unlocked = idx + 2;
        }
      }
    } else if (spec.officialDaily && spec.dailyDate != null && !state.dailyRecords.containsKey(spec.dailyDate)) {
      state.dailyRecords[spec.dailyDate!] = DailyRecord(date: spec.dailyDate!, score: score.total, accuracy: accuracy);
      dailyRecorded = true;
    }

    return RoundOutcome(
      spec: spec,
      evaluation: eval,
      score: score,
      stars: stars,
      passed: passed,
      xpGained: xpGained,
      xpBefore: xpBefore,
      xpAfter: player.xp,
      playerLevelBefore: levelBefore,
      playerLevelAfter: player.xpLevel,
      newBest: newBest,
      unlockedLevel: unlocked,
      officialDailyRecorded: dailyRecorded,
    );
  }
}
