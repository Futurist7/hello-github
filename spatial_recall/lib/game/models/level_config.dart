/// Data describing a single round's difficulty. Levels, the daily challenge
/// and practice rounds all share this shape.
class LevelConfig {
  const LevelConfig({
    required this.level,
    required this.gridSize,
    required this.tileCount,
    required this.memorySeconds,
    required this.passPercentage,
  });

  final int level;
  final int gridSize;
  final int tileCount;
  final int memorySeconds;

  /// Minimum accuracy (0–100) needed to complete the level.
  final int passPercentage;

  /// 1–5 rating shown on the level intro screen.
  int get difficulty {
    // Density of the board plus time pressure, mapped onto five stars.
    final density = tileCount / (gridSize * gridSize);
    final pressure = tileCount / memorySeconds;
    final raw = density * 8 + pressure * 1.2;
    return raw.round().clamp(1, 5);
  }
}
