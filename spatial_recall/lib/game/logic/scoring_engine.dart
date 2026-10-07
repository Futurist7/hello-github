import '../models/round_result.dart';

/// Pure scoring rules.
class ScoringEngine {
  static const pointsPerTile = 100;

  /// Streak multiplier grows 10% per consecutive success, capped at +50%.
  static const maxStreakMultiplier = 1.5;

  /// Recall time that earns no speed bonus: a few seconds plus ~2s per tile.
  static Duration relaxedRecallTime(int tileCount) => Duration(milliseconds: 4000 + tileCount * 2000);

  /// Scores one round. [previousPerfectStreak] is the number of perfect
  /// rounds immediately before this one in the session.
  static ScoreBreakdown score({
    required int correct,
    required int target,
    required Duration recallTime,
    required int previousPerfectStreak,
  }) {
    final base = correct * pointsPerTile;
    final speedFactor = speedFactorFor(target, recallTime);
    final speedBonus = correct == 0 ? 0 : (base * 0.25 * speedFactor).round();
    final perfect = target > 0 && correct == target;
    final perfectBonus = perfect ? 50 + target * 15 : 0;
    final multiplier = perfect ? streakMultiplier(previousPerfectStreak) : 1.0;
    final streakBonus = ((base + speedBonus + perfectBonus) * (multiplier - 1)).round();
    return ScoreBreakdown(
      base: base,
      speedBonus: speedBonus,
      perfectBonus: perfectBonus,
      streakBonus: streakBonus,
      speed: speedFactor >= 0.5
          ? SpeedRating.fast
          : speedFactor >= 0.2
          ? SpeedRating.steady
          : SpeedRating.relaxed,
    );
  }

  /// 1.0 for an instant answer, 0.0 at or beyond [relaxedRecallTime].
  static double speedFactorFor(int target, Duration recallTime) {
    final limit = relaxedRecallTime(target).inMilliseconds;
    final f = 1 - recallTime.inMilliseconds / limit;
    return f.clamp(0.0, 1.0);
  }

  static double streakMultiplier(int previousSuccessStreak) {
    final m = 1 + 0.1 * previousSuccessStreak;
    return m > maxStreakMultiplier ? maxStreakMultiplier : m;
  }

  /// 0–5 stars from session accuracy. Promotion (80%) is three stars.
  static int stars(double accuracy) {
    if (accuracy >= 97) return 5;
    if (accuracy >= 90) return 4;
    if (accuracy >= 80) return 3;
    if (accuracy >= 60) return 2;
    if (accuracy > 0) return 1;
    return 0;
  }

  /// XP for a session: scales with accuracy and with the number of rounds
  /// (a 10-round level session is worth twice a 5-round daily).
  static int xpFor(double accuracy, {int rounds = 10}) {
    final perFive = accuracy >= 100
        ? 100
        : accuracy >= 80
        ? 75
        : accuracy >= 60
        ? 50
        : 25;
    return (perFive * rounds / 5).round();
  }
}

/// Player level curve: reaching level L needs 50·L·(L−1) total XP, so each
/// level costs 100 XP more than the last (100, 200, 300…).
class XpLevels {
  static int totalXpForLevel(int level) => 50 * level * (level - 1);

  static int levelForXp(int xp) {
    var level = 1;
    while (totalXpForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  /// XP earned inside the current level and the size of that level.
  static (int into, int needed) progress(int xp) {
    final level = levelForXp(xp);
    final start = totalXpForLevel(level);
    return (xp - start, totalXpForLevel(level + 1) - start);
  }
}
