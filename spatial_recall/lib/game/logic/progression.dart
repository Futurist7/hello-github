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

/// Applies a finished session to the player's progression.
class ProgressionEngine {
  /// Scores each round; the streak bonus follows consecutive perfect rounds.
  static List<ScoreBreakdown> scoreRounds(List<RoundEvaluation> rounds) {
    var streak = 0;
    final scores = <ScoreBreakdown>[];
    for (final r in rounds) {
      scores.add(
        ScoringEngine.score(
          correct: r.correctCount,
          target: r.targetCount,
          recallTime: r.recallTime,
          previousPerfectStreak: streak,
        ),
      );
      streak = r.perfect ? streak + 1 : 0;
    }
    return scores;
  }

  static SessionOutcome apply(ProgressState state, SessionSpec spec, List<RoundEvaluation> rounds, DateTime now) {
    final player = state.player;
    final accuracy = sessionAccuracy(rounds);
    final promoted = accuracy >= spec.config.passPercentage;

    final roundScores = scoreRounds(rounds);
    final score = roundScores.fold(ScoreBreakdown.zero, (a, b) => a + b);
    final stars = ScoringEngine.stars(accuracy);
    final xpGained = ScoringEngine.xpFor(accuracy, rounds: rounds.length);

    final xpBefore = player.xp;
    final levelBefore = XpLevels.levelForXp(xpBefore);
    final newBest = score.total > player.bestScore;

    player.xp += xpGained;
    player.xpLevel = XpLevels.levelForXp(player.xp);
    player.averageAccuracy = (player.averageAccuracy * player.gamesPlayed + accuracy) / (player.gamesPlayed + 1);
    player.gamesPlayed += 1;
    player.totalScore += score.total;
    if (newBest) player.bestScore = score.total;
    player.successStreak = promoted ? player.successStreak + 1 : 0;
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
      if (promoted) {
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

    return SessionOutcome(
      spec: spec,
      rounds: List.unmodifiable(rounds),
      roundScores: roundScores,
      score: score,
      stars: stars,
      promoted: promoted,
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
