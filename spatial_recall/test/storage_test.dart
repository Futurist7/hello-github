import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spatial_recall/game/logic/progression.dart';
import 'package:spatial_recall/game/models/player_data.dart';
import 'package:spatial_recall/services/storage_service.dart';

void main() {
  test('progress round-trips through storage', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.open();
    final state = ProgressState.initial();
    state.player
      ..xp = 420
      ..xpLevel = 3
      ..gamesPlayed = 7
      ..bestScore = 1300
      ..averageAccuracy = 81.5
      ..currentStreak = 2
      ..longestStreak = 5
      ..lastPlayedDate = DateTime(2026, 10, 6);
    state.levels[0]
      ..completed = true
      ..stars = 4
      ..bestScore = 500;
    state.levels[1].unlocked = true;
    state.dailyRecords['2026-10-06'] = DailyRecord(date: '2026-10-06', score: 900, accuracy: 90);
    await storage.saveProgress(state);
    await storage.saveSettings(GameSettings(sound: false, haptics: true, reducedMotion: true));

    final reopened = StorageService(await SharedPreferences.getInstance());
    final loaded = reopened.loadProgress();
    expect(loaded.player.xp, 420);
    expect(loaded.player.averageAccuracy, 81.5);
    expect(loaded.player.lastPlayedDate, DateTime(2026, 10, 6));
    expect(loaded.levels[0].completed, isTrue);
    expect(loaded.levels[0].stars, 4);
    expect(loaded.levels[1].unlocked, isTrue);
    expect(loaded.levels[2].unlocked, isFalse);
    expect(loaded.dailyRecords['2026-10-06']!.score, 900);
    final settings = reopened.loadSettings();
    expect(settings.sound, isFalse);
    expect(settings.reducedMotion, isTrue);
  });

  test('corrupt data falls back to defaults without crashing', () async {
    SharedPreferences.setMockInitialValues({
      'player.v1': '{not json',
      'levels.v1': '{"levels": [42, {"completed": true, "stars": 99, "bestScore": -5}]}',
      'daily.v1': '{"records": [{"date": "garbage", "score": 1}, {"date": "2026-10-01", "score": 10, "accuracy": 50}]}',
      'settings.v1': '[]',
    });
    final storage = await StorageService.open();
    final loaded = storage.loadProgress();
    expect(loaded.player.xp, 0);
    expect(loaded.levels[0].unlocked, isTrue);
    expect(loaded.levels[1].completed, isTrue);
    expect(loaded.levels[1].stars, 5);
    expect(loaded.levels[1].bestScore, 0);
    // Repaired: the level after a completed one is unlocked.
    expect(loaded.levels[2].unlocked, isTrue);
    expect(loaded.dailyRecords.keys, ['2026-10-01']);
    expect(storage.loadSettings().sound, isTrue);
  });

  test('reset clears progress but keeps settings', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.open();
    final state = ProgressState.initial()..player.xp = 999;
    await storage.saveProgress(state);
    await storage.saveSettings(GameSettings(sound: false));
    await storage.resetProgress();
    expect(storage.loadProgress().player.xp, 0);
    expect(storage.loadSettings().sound, isFalse);
  });
}
