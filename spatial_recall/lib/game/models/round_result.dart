import 'level_config.dart';
import 'pattern.dart';
import 'tile_position.dart';

enum RoundMode { level, daily }

/// Everything needed to play one round. Created once per round so the
/// pattern stays stable across widget rebuilds.
class RoundSpec {
  RoundSpec({
    required this.mode,
    required this.config,
    required this.pattern,
    this.dailyDate,
    this.officialDaily = false,
  });

  final RoundMode mode;
  final LevelConfig config;
  final Pattern pattern;

  /// `yyyy-mm-dd` of the daily challenge being played.
  final String? dailyDate;

  /// Whether this attempt counts as the official daily result.
  final bool officialDaily;
}

/// The raw outcome of a round, before scoring/progression is applied.
class RoundEvaluation {
  RoundEvaluation({required this.target, required this.selected, required this.recallTime});

  final Set<TilePosition> target;
  final Set<TilePosition> selected;
  final Duration recallTime;

  Set<TilePosition> get correct => target.intersection(selected);
  Set<TilePosition> get wrong => selected.difference(target);
  Set<TilePosition> get missed => target.difference(selected);

  int get correctCount => correct.length;
  int get targetCount => target.length;

  /// correct / target × 100. No partial credit for neighbouring tiles.
  double get accuracy => targetCount == 0 ? 0 : correctCount / targetCount * 100;
}

enum SpeedRating { fast, steady, relaxed }

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.base,
    required this.speedBonus,
    required this.perfectBonus,
    required this.streakBonus,
    required this.speed,
  });

  final int base;
  final int speedBonus;
  final int perfectBonus;
  final int streakBonus;
  final SpeedRating speed;

  int get total => base + speedBonus + perfectBonus + streakBonus;
}

/// What happened to the player's progression as a result of a round.
class RoundOutcome {
  RoundOutcome({
    required this.spec,
    required this.evaluation,
    required this.score,
    required this.stars,
    required this.passed,
    required this.xpGained,
    required this.xpBefore,
    required this.xpAfter,
    required this.playerLevelBefore,
    required this.playerLevelAfter,
    required this.newBest,
    this.unlockedLevel,
    this.officialDailyRecorded = false,
  });

  final RoundSpec spec;
  final RoundEvaluation evaluation;
  final ScoreBreakdown score;
  final int stars;
  final bool passed;
  final int xpGained;
  final int xpBefore;
  final int xpAfter;
  final int playerLevelBefore;
  final int playerLevelAfter;
  final bool newBest;
  final int? unlockedLevel;
  final bool officialDailyRecorded;

  bool get leveledUp => playerLevelAfter > playerLevelBefore;
}
