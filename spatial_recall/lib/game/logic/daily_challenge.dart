import '../models/level_config.dart';
import '../models/pattern.dart';
import '../models/player_data.dart';
import 'pattern_generator.dart';

/// Deterministic daily challenge: the date is the seed, so every player gets
/// the same boards on the same day.
class DailyChallenge {
  DailyChallenge._(this.date, this.config, this.patterns);

  static const rounds = 5;

  final DateTime date;
  final LevelConfig config;

  /// One pattern per round, fixed for the day.
  final List<Pattern> patterns;

  String get key => dateKey(date);

  static int seedFor(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  factory DailyChallenge.forDate(DateTime date) {
    final day = dateOnly(date);
    final seed = seedFor(day);
    // Derive the shape from a hash of the seed so it varies day to day.
    final h = _mix(seed);
    final gridSize = 6 + h % 2; // 6×6 or 7×7
    final tiles = gridSize == 6 ? 6 + (h >> 3) % 3 : 7 + (h >> 3) % 3;
    final memoryMs = 3500 + ((h >> 7) % 3) * 500; // 3.5–4.5s
    final config = LevelConfig(
      level: 0,
      gridSize: gridSize,
      tileCount: tiles,
      memoryMs: memoryMs,
      rounds: rounds,
      passPercentage: 80,
    );
    return DailyChallenge._(day, config, [
      for (var r = 0; r < rounds; r++) generatePattern(gridSize: gridSize, tileCount: tiles, seed: seed * 10 + r),
    ]);
  }

  static int _mix(int x) {
    var h = x & 0x7fffffff;
    h = ((h >> 16) ^ h) * 0x45d9f3b & 0x7fffffff;
    h = ((h >> 16) ^ h) * 0x45d9f3b & 0x7fffffff;
    return (h >> 16) ^ h;
  }
}
