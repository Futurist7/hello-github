// Renders every screen to PNG for visual review:
//   flutter test test/screenshots_test.dart [--dart-define=SHOTS_DIR=/some/dir]
// Also runs with the normal suite as a multi-device smoke test.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spatial_recall/app/app.dart';
import 'package:spatial_recall/app/routes.dart';
import 'package:spatial_recall/game/models/tile_position.dart';
import 'package:spatial_recall/screens/game_screen.dart';
import 'package:spatial_recall/services/audio_service.dart';
import 'package:spatial_recall/services/haptic_service.dart';
import 'package:spatial_recall/services/storage_service.dart';
import 'package:spatial_recall/state/app_state.dart';

const outDir = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/screenshots');

Future<void> shot(WidgetTester tester, String name) async {
  final element = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$outDir/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void phone(WidgetTester tester, double w, double h) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 24 * 2);
  addTearDown(tester.view.reset);
}

Map<String, Object> progressPrefs() => {
  'tutorial_seen.v1': true,
  'player.v1':
      '{"xp":2430,"xpLevel":7,"gamesPlayed":42,"totalScore":30000,"bestScore":8420,"averageAccuracy":87,"currentStreak":7,"longestStreak":12,"lastPlayedDate":"${_today(-1)}","successStreak":2}',
  'levels.v1':
      '{"levels":[${List.generate(30, (i) => i < 6
          ? '{"unlocked":true,"completed":true,"bestScore":${900 + i * 120},"bestAccuracy":100,"stars":${i.isEven ? 5 : 4}}'
          : i == 6
          ? '{"unlocked":true}'
          : '{}').join(',')}]}',
};

String _today(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Future<void> boot(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await StorageService.open();
  final state = AppState(storage: storage, audio: AudioService(), haptics: HapticService());
  await tester.pumpWidget(SpatialRecallApp(key: UniqueKey(), state: state));
}

Future<void> settle(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  testWidgets('screens', (tester) async {
    phone(tester, 360, 780);
    await boot(tester, {});
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, '01_splash');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await shot(tester, '02_tutorial');

    await boot(tester, progressPrefs());
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    await shot(tester, '03_home');
    for (final (tab, name) in [('Levels', '04_levels'), ('Daily', '05_daily'), ('Stats', '06_stats')]) {
      await tester.tap(find.text(tab));
      await settle(tester);
      await shot(tester, name);
    }
    await tester.tap(find.text('Home'));
    await settle(tester);
    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    await shot(tester, '07_settings');
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('CONTINUE'));
    await settle(tester);
    await shot(tester, '08_level_intro');
    await tester.tap(find.text('START'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '09_memorize');
    final spec = tester.widget<GameScreen>(find.byType(GameScreen)).spec;
    await tester.pump(Duration(seconds: spec.config.memorySeconds - 3));
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, '10_memorize_countdown');
    await tester.pump(const Duration(seconds: 4));
    final target = spec.pattern.positions.toList();
    final wrong = [
      for (var r = 0; r < spec.pattern.gridSize; r++)
        for (var c = 0; c < spec.pattern.gridSize; c++) TilePosition(r, c),
    ].where((t) => !spec.pattern.positions.contains(t)).toList();
    final picks = [...target.take(target.length - 2), ...wrong.take(2)];
    for (final t in picks.take(picks.length - 1)) {
      await tester.tap(find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}'));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '11_recall');
    final last = picks.last;
    await tester.tap(find.bySemanticsLabel('Row ${last.row + 1}, Column ${last.column + 1}'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '12_checking');
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester, 2500);
    await shot(tester, '13_results_partial');

    // Perfect round on 8×8 with the quit dialog and pause overlay.
    final ctx = tester.element(find.byType(Scaffold).first);
    Nav.play(ctx, Rounds.level(20), replace: true);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '14_memorize_8x8');
    await tester.binding.handlePopRoute();
    await settle(tester, 300);
    await shot(tester, '15_quit_dialog');
    await tester.tap(find.text('CONTINUE PLAYING'));
    await settle(tester, 300);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester, 100);
    await shot(tester, '16_paused');
    await tester.tap(find.text('RESUME'));
    final spec2 = tester.widget<GameScreen>(find.byType(GameScreen)).spec;
    await tester.pump(Duration(seconds: spec2.config.memorySeconds + 1));
    await tester.pump(const Duration(milliseconds: 400));
    for (final t in spec2.pattern.positions) {
      await tester.tap(find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}'));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('CHECK ANSWER'));
    await tester.pump(const Duration(milliseconds: 900));
    await settle(tester, 400);
    await shot(tester, '17_results_perfect');
    await tester.pump(const Duration(seconds: 3));
    await shot(tester, '18_results_perfect_settled');
  });

  testWidgets('small phone', (tester) async {
    phone(tester, 320, 568);
    await boot(tester, progressPrefs());
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    await shot(tester, '20_small_home');
    final ctx = tester.element(find.byType(Scaffold).first);
    Nav.play(ctx, Rounds.level(25));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '21_small_memorize_8x8');
    final spec = tester.widget<GameScreen>(find.byType(GameScreen)).spec;
    await tester.pump(Duration(seconds: spec.config.memorySeconds + 1));
    await tester.pump(const Duration(milliseconds: 400));
    for (final t in spec.pattern.positions.take(5)) {
      await tester.tap(find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}'));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '22_small_recall_8x8');
  });

  testWidgets('tablet', (tester) async {
    phone(tester, 800, 1280);
    await boot(tester, progressPrefs());
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    final ctx = tester.element(find.byType(Scaffold).first);
    Nav.play(ctx, Rounds.level(12));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '30_tablet_memorize');
  });
}
