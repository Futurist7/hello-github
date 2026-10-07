import '../models/level_config.dart';

/// The 30-level campaign, defined as data.
class LevelManager {
  // (grid, tiles, seconds) for each level, in order.
  static const List<(int, int, int)> _table = [
    (5, 3, 20), (5, 4, 18), (5, 5, 17), (5, 6, 16), (5, 7, 15), //  1–5
    (6, 7, 14), (6, 8, 13), (6, 9, 12), (6, 10, 11), (6, 11, 10), //  6–10
    (7, 10, 10), (7, 11, 9), (7, 12, 9), (7, 13, 8), (7, 14, 8), // 11–15
    (8, 13, 8), (8, 14, 7), (8, 15, 7), (8, 16, 6), (8, 17, 6), // 16–20
    // 21–30: the board stays 8×8 so tiles keep a comfortable touch size on
    // phones; difficulty comes from more tiles and less time.
    (8, 18, 7), (8, 18, 6), (8, 19, 6), (8, 19, 6), (8, 20, 6), // 21–25
    (8, 20, 5), (8, 21, 5), (8, 22, 5), (8, 23, 5), (8, 24, 5), // 26–30
  ];

  static int get levelCount => _table.length;

  static final List<LevelConfig> levels = [
    for (var i = 0; i < _table.length; i++)
      LevelConfig(
        level: i + 1,
        gridSize: _table[i].$1,
        tileCount: _table[i].$2,
        memorySeconds: _table[i].$3,
        passPercentage: _passPercentage(i + 1),
      ),
  ];

  static int _passPercentage(int level) {
    if (level <= 5) return 60;
    if (level <= 15) return 70;
    return 75;
  }

  static LevelConfig config(int level) => levels[level.clamp(1, levelCount) - 1];

  /// Minimum correct tiles to pass a level.
  static int tilesToPass(LevelConfig c) => (c.tileCount * c.passPercentage / 100).ceil();
}
