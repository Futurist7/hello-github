import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/logic/level_manager.dart';
import '../game/logic/progression.dart';
import '../game/models/player_data.dart';

/// Local, offline persistence on top of SharedPreferences.
///
/// Every blob is JSON with a versioned key. Corrupt or unexpected data is
/// discarded per-section (falling back to defaults) instead of crashing.
class StorageService {
  StorageService(this._prefs);

  static const _playerKey = 'player.v1';
  static const _levelsKey = 'levels.v1';
  static const _dailyKey = 'daily.v1';
  static const _settingsKey = 'settings.v1';
  static const _tutorialKey = 'tutorial_seen.v1';

  final SharedPreferences _prefs;

  static Future<StorageService> open() async => StorageService(await SharedPreferences.getInstance());

  Map<String, dynamic>? _readMap(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('Discarding corrupt "$key": $e');
      return null;
    }
  }

  Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    try {
      await _prefs.setString(key, jsonEncode(value));
    } catch (e) {
      debugPrint('Failed to save "$key": $e');
    }
  }

  ProgressState loadProgress() {
    final state = ProgressState.initial();
    final playerJson = _readMap(_playerKey);
    final player = playerJson == null ? state.player : _safe(() => PlayerData.fromJson(playerJson)) ?? state.player;

    final levelsJson = _readMap(_levelsKey);
    final levels = state.levels;
    final list = levelsJson?['levels'];
    if (list is List) {
      for (var i = 0; i < levels.length && i < list.length; i++) {
        final item = list[i];
        if (item is Map<String, dynamic>) {
          levels[i] = _safe(() => LevelProgress.fromJson(item)) ?? levels[i];
        }
      }
    }
    // Repair: level 1 is always open, and anything after a completed level is unlocked.
    levels[0].unlocked = true;
    for (var i = 0; i < levels.length - 1; i++) {
      if (levels[i].completed) levels[i + 1].unlocked = true;
    }

    final daily = <String, DailyRecord>{};
    final dailyJson = _readMap(_dailyKey);
    final records = dailyJson?['records'];
    if (records is List) {
      for (final r in records) {
        final rec = DailyRecord.fromJson(r);
        if (rec != null) daily[rec.date] = rec;
      }
    }
    return ProgressState(player: player, levels: levels, dailyRecords: daily);
  }

  Future<void> saveProgress(ProgressState state) async {
    await _writeMap(_playerKey, state.player.toJson());
    await _writeMap(_levelsKey, {
      'levels': [for (final l in state.levels.take(LevelManager.levelCount)) l.toJson()],
    });
    await _writeMap(_dailyKey, {
      'records': [for (final r in state.dailyRecords.values) r.toJson()],
    });
  }

  GameSettings loadSettings() {
    final json = _readMap(_settingsKey);
    return json == null ? GameSettings() : _safe(() => GameSettings.fromJson(json)) ?? GameSettings();
  }

  Future<void> saveSettings(GameSettings s) => _writeMap(_settingsKey, s.toJson());

  bool get tutorialSeen => _prefs.getBool(_tutorialKey) ?? false;
  Future<void> setTutorialSeen() => _prefs.setBool(_tutorialKey, true);

  /// Clears progression but keeps settings and the tutorial flag.
  Future<void> resetProgress() async {
    await _prefs.remove(_playerKey);
    await _prefs.remove(_levelsKey);
    await _prefs.remove(_dailyKey);
  }

  static T? _safe<T>(T Function() f) {
    try {
      return f();
    } catch (e) {
      debugPrint('Discarding invalid save data: $e');
      return null;
    }
  }
}
