import '../models/player_data.dart';

/// Daily play streak based on local calendar dates.
class StreakManager {
  /// Whole calendar days between two dates, immune to DST shifts.
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Updates [player] for a round completed on [now].
  static void recordPlay(PlayerData player, DateTime now) {
    final today = dateOnly(now);
    final last = player.lastPlayedDate;
    if (last == null) {
      player.currentStreak = 1;
    } else {
      final gap = daysBetween(last, today);
      if (gap == 0) {
        // Already played today: keep the streak (at least 1).
        if (player.currentStreak < 1) player.currentStreak = 1;
      } else if (gap == 1) {
        player.currentStreak += 1;
      } else if (gap > 1) {
        player.currentStreak = 1;
      } else {
        // Clock moved backwards (device time change): don't reward or punish.
        if (player.currentStreak < 1) player.currentStreak = 1;
        return;
      }
    }
    player.lastPlayedDate = today;
    if (player.currentStreak > player.longestStreak) {
      player.longestStreak = player.currentStreak;
    }
  }

  /// The streak to display today: it lapses if yesterday was missed.
  static int effectiveStreak(PlayerData player, DateTime now) {
    final last = player.lastPlayedDate;
    if (last == null) return 0;
    final gap = daysBetween(last, dateOnly(now));
    return gap <= 1 ? player.currentStreak : 0;
  }
}
