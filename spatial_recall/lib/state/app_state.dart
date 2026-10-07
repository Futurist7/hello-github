import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

import '../game/logic/daily_challenge.dart';
import '../game/logic/progression.dart';
import '../game/logic/streak_manager.dart';
import '../game/models/player_data.dart';
import '../game/models/round_result.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/storage_service.dart';

/// App-wide state: progression, settings and services.
class AppState extends ChangeNotifier {
  AppState({required this.storage, required this.audio, required this.haptics})
    : _progress = storage.loadProgress(),
      _settings = storage.loadSettings() {
    _applySettings();
  }

  final StorageService storage;
  final AudioService audio;
  final HapticService haptics;

  ProgressState _progress;
  GameSettings _settings;

  ProgressState get progress => _progress;
  PlayerData get player => _progress.player;
  GameSettings get settings => _settings;
  bool get tutorialSeen => storage.tutorialSeen;

  DateTime get now => clock.now();
  int get streak => StreakManager.effectiveStreak(player, now);

  DailyChallenge get todaysChallenge => DailyChallenge.forDate(now);
  DailyRecord? dailyRecordFor(String key) => _progress.dailyRecords[key];

  void _applySettings() {
    audio.enabled = _settings.sound;
    haptics.enabled = _settings.haptics;
  }

  Future<void> updateSettings(GameSettings s) async {
    _settings = s;
    _applySettings();
    notifyListeners();
    await storage.saveSettings(s);
  }

  Future<void> markTutorialSeen() async {
    await storage.setTutorialSeen();
    notifyListeners();
  }

  /// Applies a finished session and persists immediately.
  Future<SessionOutcome> recordSession(SessionSpec spec, List<RoundEvaluation> rounds) async {
    final outcome = ProgressionEngine.apply(_progress, spec, rounds, now);
    notifyListeners();
    await storage.saveProgress(_progress);
    return outcome;
  }

  Future<void> resetProgress() async {
    await storage.resetProgress();
    _progress = ProgressState.initial();
    notifyListeners();
  }
}

/// Provides [AppState] to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}
