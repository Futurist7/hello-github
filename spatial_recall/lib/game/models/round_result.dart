import 'level_config.dart';
import 'pattern.dart';
import 'tile_position.dart';

enum RoundMode { level, daily }

/// One round: a pattern on a board of [config]'s size.
class RoundSpec {
  RoundSpec({required this.config, required this.pattern});

  final LevelConfig config;
  final Pattern pattern;
}

/// A full session (10 rounds for a level). All patterns are created up
/// front so they stay stable across widget rebuilds.
class SessionSpec {
  SessionSpec({
    required this.mode,
    required this.config,
    required this.patterns,
    this.dailyDate,
    this.officialDaily = false,
  }) : assert(patterns.length == config.rounds);

  final RoundMode mode;
  final LevelConfig config;
  final List<Pattern> patterns;

  /// `yyyy-mm-dd` of the daily challenge being played.
  final String? dailyDate;

  /// Whether this attempt counts as the official daily result.
  final bool officialDaily;

  int get rounds => patterns.length;

  RoundSpec round(int index) => RoundSpec(config: config, pattern: patterns[index]);
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
  bool get perfect => targetCount > 0 && correctCount == targetCount;

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

  static const zero = ScoreBreakdown(
    base: 0,
    speedBonus: 0,
    perfectBonus: 0,
    streakBonus: 0,
    speed: SpeedRating.relaxed,
  );

  final int base;
  final int speedBonus;
  final int perfectBonus;
  final int streakBonus;
  final SpeedRating speed;

  int get total => base + speedBonus + perfectBonus + streakBonus;

  ScoreBreakdown operator +(ScoreBreakdown o) => ScoreBreakdown(
    base: base + o.base,
    speedBonus: speedBonus + o.speedBonus,
    perfectBonus: perfectBonus + o.perfectBonus,
    streakBonus: streakBonus + o.streakBonus,
    speed: speed,
  );
}

/// What happened to the player's progression after a session.
class SessionOutcome {
  SessionOutcome({
    required this.spec,
    required this.rounds,
    required this.roundScores,
    required this.score,
    required this.stars,
    required this.promoted,
    required this.xpGained,
    required this.xpBefore,
    required this.xpAfter,
    required this.playerLevelBefore,
    required this.playerLevelAfter,
    required this.newBest,
    this.unlockedLevel,
    this.officialDailyRecorded = false,
  });

  final SessionSpec spec;
  final List<RoundEvaluation> rounds;
  final List<ScoreBreakdown> roundScores;

  /// Sum of all rounds.
  final ScoreBreakdown score;
  final int stars;

  /// Reached the promotion accuracy (for levels: next level unlocked).
  final bool promoted;
  final int xpGained;
  final int xpBefore;
  final int xpAfter;
  final int playerLevelBefore;
  final int playerLevelAfter;
  final bool newBest;
  final int? unlockedLevel;
  final bool officialDailyRecorded;

  int get correct => rounds.fold(0, (s, r) => s + r.correctCount);
  int get target => rounds.fold(0, (s, r) => s + r.targetCount);
  int get perfectRounds => rounds.where((r) => r.perfect).length;

  /// Session accuracy: all correct tiles / all target tiles.
  double get accuracy => sessionAccuracy(rounds);

  bool get leveledUp => playerLevelAfter > playerLevelBefore;
}

double sessionAccuracy(List<RoundEvaluation> rounds) {
  final target = rounds.fold(0, (s, r) => s + r.targetCount);
  final correct = rounds.fold(0, (s, r) => s + r.correctCount);
  return target == 0 ? 0 : correct / target * 100;
}
