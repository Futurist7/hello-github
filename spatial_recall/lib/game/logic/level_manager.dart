import '../models/level_config.dart';

/// The 30-level campaign, defined as data.
///
/// Every level is a session of 10 rounds. Memory time never exceeds 5s;
/// difficulty comes from bigger boards, more tiles and less time.
class LevelManager {
  static const roundsPerLevel = 10;

  /// Session accuracy needed to be promoted.
  static const promotionAccuracy = 80;

  // (grid, tiles, memory ms) for each level, in order.
  static const List<(int, int, int)> _table = [
    (5, 3, 5000), (5, 4, 5000), (5, 4, 4500), (5, 5, 4500), (5, 5, 4000), //  1–5
    (6, 5, 4500), (6, 6, 4500), (6, 6, 4000), (6, 7, 4000), (6, 7, 3500), //  6–10
    (6, 8, 4000), (7, 8, 4000), (7, 9, 4000), (7, 9, 3500), (7, 10, 3500), // 11–15
    (7, 10, 3000), (7, 11, 3500), (8, 11, 3500), (8, 12, 3500), (8, 12, 3000), // 16–20
    (8, 13, 3500), (8, 13, 3000), (8, 14, 3000), (8, 14, 2500), (8, 15, 3000), // 21–25
    (8, 15, 2500), (8, 16, 3000), (8, 16, 2500), (8, 17, 2500), (8, 18, 2500), // 26–30
  ];

  static int get levelCount => _table.length;

  static final List<LevelConfig> levels = [
    for (var i = 0; i < _table.length; i++)
      LevelConfig(
        level: i + 1,
        gridSize: _table[i].$1,
        tileCount: _table[i].$2,
        memoryMs: _table[i].$3,
        rounds: roundsPerLevel,
        passPercentage: promotionAccuracy,
      ),
  ];

  static LevelConfig config(int level) => levels[level.clamp(1, levelCount) - 1];
}
