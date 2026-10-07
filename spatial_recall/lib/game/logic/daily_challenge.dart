import '../models/level_config.dart';
import '../models/pattern.dart';
import '../models/player_data.dart';
import 'pattern_generator.dart';

/// Deterministic daily challenge: the date is the seed, so every player gets
/// the same board on the same day.
class DailyChallenge {
  DailyChallenge._(this.date, this.config, this.pattern);

  final DateTime date;
  final LevelConfig config;
  final Pattern pattern;

  String get key => dateKey(date);

  static int seedFor(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  factory DailyChallenge.forDate(DateTime date) {
    final day = dateOnly(date);
    final seed = seedFor(day);
    // Derive the shape from a hash of the seed so it varies day to day.
    final h = _mix(seed);
    final gridSize = 6 + h % 2; // 6×6 or 7×7
    final tiles = gridSize == 6 ? 9 + (h >> 3) % 3 : 10 + (h >> 3) % 3;
    final seconds = 8 + (h >> 7) % 3;
    final config = LevelConfig(
      level: 0,
      gridSize: gridSize,
      tileCount: tiles,
      memorySeconds: seconds,
      passPercentage: 70,
    );
    return DailyChallenge._(day, config, generatePattern(gridSize: gridSize, tileCount: tiles, seed: seed));
  }

  static int _mix(int x) {
    var h = x & 0x7fffffff;
    h = ((h >> 16) ^ h) * 0x45d9f3b & 0x7fffffff;
    h = ((h >> 16) ^ h) * 0x45d9f3b & 0x7fffffff;
    return (h >> 16) ^ h;
  }
}
