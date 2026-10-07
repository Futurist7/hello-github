/// Persistent, level-independent player progression.
class PlayerData {
  PlayerData({
    this.xp = 0,
    this.xpLevel = 1,
    this.gamesPlayed = 0,
    this.totalScore = 0,
    this.bestScore = 0,
    this.averageAccuracy = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastPlayedDate,
    this.successStreak = 0,
  });

  int xp;
  int xpLevel;
  int gamesPlayed;
  int totalScore;
  int bestScore;

  /// Running mean of round accuracy, 0–100.
  double averageAccuracy;

  /// Consecutive calendar days played.
  int currentStreak;
  int longestStreak;

  /// Local calendar date (time stripped) of the last completed round.
  DateTime? lastPlayedDate;

  /// Consecutive passed rounds, used for the in-game streak bonus.
  int successStreak;

  PlayerData copy() => PlayerData.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'xpLevel': xpLevel,
    'gamesPlayed': gamesPlayed,
    'totalScore': totalScore,
    'bestScore': bestScore,
    'averageAccuracy': averageAccuracy,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastPlayedDate': lastPlayedDate == null ? null : dateKey(lastPlayedDate!),
    'successStreak': successStreak,
  };

  factory PlayerData.fromJson(Map<String, dynamic> json) => PlayerData(
    xp: _int(json['xp']),
    xpLevel: _int(json['xpLevel'], 1).clamp(1, 9999),
    gamesPlayed: _int(json['gamesPlayed']),
    totalScore: _int(json['totalScore']),
    bestScore: _int(json['bestScore']),
    averageAccuracy: _double(json['averageAccuracy']).clamp(0, 100),
    currentStreak: _int(json['currentStreak']),
    longestStreak: _int(json['longestStreak']),
    lastPlayedDate: parseDateKey(json['lastPlayedDate']),
    successStreak: _int(json['successStreak']),
  );
}

/// Best result for one level.
class LevelProgress {
  LevelProgress({
    this.unlocked = false,
    this.completed = false,
    this.bestScore = 0,
    this.bestAccuracy = 0,
    this.stars = 0,
  });

  bool unlocked;
  bool completed;
  int bestScore;
  double bestAccuracy;

  /// 0–5.
  int stars;

  LevelProgress copy() => LevelProgress.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'unlocked': unlocked,
    'completed': completed,
    'bestScore': bestScore,
    'bestAccuracy': bestAccuracy,
    'stars': stars,
  };

  factory LevelProgress.fromJson(Map<String, dynamic> json) => LevelProgress(
    unlocked: json['unlocked'] == true,
    completed: json['completed'] == true,
    bestScore: _int(json['bestScore']),
    bestAccuracy: _double(json['bestAccuracy']).clamp(0, 100),
    stars: _int(json['stars']).clamp(0, 5),
  );
}

/// The official (first) daily challenge result for a date.
class DailyRecord {
  DailyRecord({required this.date, required this.score, required this.accuracy});

  final String date;
  final int score;
  final double accuracy;

  Map<String, dynamic> toJson() => {'date': date, 'score': score, 'accuracy': accuracy};

  static DailyRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = json['date'];
    if (date is! String || parseDateKey(date) == null) return null;
    return DailyRecord(date: date, score: _int(json['score']), accuracy: _double(json['accuracy']).clamp(0, 100));
  }
}

class GameSettings {
  GameSettings({this.sound = true, this.haptics = true, this.reducedMotion = false});

  bool sound;
  bool haptics;
  bool reducedMotion;

  GameSettings copyWith({bool? sound, bool? haptics, bool? reducedMotion}) => GameSettings(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );

  Map<String, dynamic> toJson() => {'sound': sound, 'haptics': haptics, 'reducedMotion': reducedMotion};

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
    sound: json['sound'] != false,
    haptics: json['haptics'] != false,
    reducedMotion: json['reducedMotion'] == true,
  );
}

/// Strips the time component, keeping the local calendar date.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `yyyy-mm-dd` for a local calendar date.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d);
}

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v < 0 ? fallback : v;
  if (v is num && v.isFinite) return v < 0 ? fallback : v.toInt();
  return fallback;
}

double _double(Object? v) => v is num && v.isFinite ? v.toDouble() : 0;
