import '../models/round_result.dart';

/// Pure scoring rules.
class ScoringEngine {
  static const pointsPerTile = 100;

  /// Streak multiplier grows 10% per consecutive success, capped at +50%.
  static const maxStreakMultiplier = 1.5;

  /// Recall time that earns no speed bonus: a few seconds plus ~2s per tile.
  static Duration relaxedRecallTime(int tileCount) => Duration(milliseconds: 4000 + tileCount * 2000);

  static ScoreBreakdown score({
    required int correct,
    required int target,
    required Duration recallTime,
    required int previousSuccessStreak,
  }) {
    final base = correct * pointsPerTile;
    final speedFactor = speedFactorFor(target, recallTime);
    final speedBonus = correct == 0 ? 0 : (base * 0.25 * speedFactor).round();
    final perfect = target > 0 && correct == target;
    final perfectBonus = perfect ? 100 + target * 25 : 0;
    final passedEnough = target > 0 && correct / target >= 0.6;
    final multiplier = passedEnough ? streakMultiplier(previousSuccessStreak) : 1.0;
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

  /// 0–5 stars from accuracy.
  static int stars(double accuracy) {
    if (accuracy >= 100) return 5;
    if (accuracy >= 75) return 4;
    if (accuracy >= 60) return 3;
    if (accuracy >= 40) return 2;
    if (accuracy > 0) return 1;
    return 0;
  }

  static int xpFor(double accuracy) {
    if (accuracy >= 100) return 100;
    if (accuracy >= 80) return 75;
    if (accuracy >= 60) return 50;
    return 25;
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
