/// Data describing one level (or the daily challenge). Levels, the daily
/// challenge and practice sessions all share this shape.
class LevelConfig {
  const LevelConfig({
    required this.level,
    required this.gridSize,
    required this.tileCount,
    required this.memoryMs,
    this.rounds = 10,
    this.passPercentage = 80,
  });

  final int level;
  final int gridSize;
  final int tileCount;

  /// How long the pattern is shown. Never more than 5 seconds.
  final int memoryMs;

  /// Rounds in one session of this level.
  final int rounds;

  /// Session accuracy (0–100) needed to be promoted to the next level.
  final int passPercentage;

  Duration get memoryDuration => Duration(milliseconds: memoryMs);

  /// "4.5s", "3s".
  String get memoryLabel {
    final s = memoryMs / 1000;
    return s == s.roundToDouble() ? '${s.round()}s' : '${s.toStringAsFixed(1)}s';
  }

  /// 1–5 rating shown on the level intro screen.
  int get difficulty {
    final density = tileCount / (gridSize * gridSize);
    final pressure = tileCount / (memoryMs / 1000);
    final raw = density * 6 + pressure * 0.55;
    return raw.round().clamp(1, 5);
  }
}
