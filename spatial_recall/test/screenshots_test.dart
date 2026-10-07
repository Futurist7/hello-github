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
    File('$outDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void phone(WidgetTester tester, double w, double h) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.padding = const FakeViewPadding(top: 24 * 2, bottom: 24 * 2);
  addTearDown(tester.view.reset);
}

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, Object> progressPrefs() => {
  'tutorial_seen.v1': true,
  'player.v1':
      '{"xp":2430,"xpLevel":7,"gamesPlayed":42,"totalScore":30000,"bestScore":8420,"averageAccuracy":87,"currentStreak":7,"longestStreak":12,"lastPlayedDate":"${_day(-1)}"}',
  'levels.v1':
      '{"levels":[${List.generate(30, (i) => i < 6
          ? '{"unlocked":true,"completed":true,"bestScore":${9000 + i * 1200},"bestAccuracy":95,"stars":${i.isEven ? 5 : 4}}'
          : i == 6
          ? '{"unlocked":true}'
          : '{}').join(',')}]}',
};

Future<void> boot(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await StorageService.open();
  final state = AppState(storage: storage, audio: AudioService(), haptics: HapticService());
  await tester.pumpWidget(SpatialRecallApp(key: UniqueKey(), state: state));
}

/// Pumps frame by frame (like a device) so animations actually play.
Future<void> settle(WidgetTester tester, [int ms = 900]) async {
  await tester.pump();
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> until(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 200 && f.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

GameScreen game(WidgetTester tester) => tester.widget<GameScreen>(find.byType(GameScreen));

Future<void> tapTiles(WidgetTester tester, Iterable<TilePosition> tiles) async {
  for (final t in tiles) {
    await tester.tap(find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}'));
    await tester.pump(const Duration(milliseconds: 30));
  }
}

List<TilePosition> wrongTiles(int grid, Set<TilePosition> target, int n) => [
  for (var r = 0; r < grid; r++)
    for (var c = 0; c < grid; c++) TilePosition(r, c),
].where((t) => !target.contains(t)).take(n).toList();

/// Plays round [i] with [right] correct tiles.
Future<void> round(WidgetTester tester, int i, int right) async {
  final p = game(tester).spec.patterns[i];
  await until(tester, find.text('Round ${i + 1} of ${game(tester).spec.rounds}'));
  await until(tester, find.text('Recreate'));
  await tester.pump(const Duration(milliseconds: 500));
  await tapTiles(tester, [...p.positions.take(right), ...wrongTiles(p.gridSize, p.positions, p.tileCount - right)]);
  await tester.tap(find.text('Check'));
  for (var k = 0; k < 18; k++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('screens', (tester) async {
    phone(tester, 360, 780);
    await boot(tester, {});
    await settle(tester, 500);
    await shot(tester, '01_splash');
    await settle(tester, 1000);
    await settle(tester, 1500);
    await shot(tester, '02_tutorial');

    await boot(tester, progressPrefs());
    await settle(tester, 2000);
    await settle(tester, 1500);
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
    await tester.binding.handlePopRoute();
    await settle(tester);

    await tester.tap(find.text('Continue'));
    await settle(tester, 1200);
    await shot(tester, '08_level_intro');
    await tester.tap(find.text('Start'));
    await settle(tester);
    await until(tester, find.text('Remember'));
    await tester.pump(const Duration(milliseconds: 1500));
    await shot(tester, '09_memorize');
    await until(tester, find.text('Recreate'));
    await tester.pump(const Duration(milliseconds: 500));
    final p0 = game(tester).spec.patterns[0];
    await tapTiles(tester, p0.positions.take(p0.tileCount - 2));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '10_recall');
    await tapTiles(tester, wrongTiles(p0.gridSize, p0.positions, 1));
    await tapTiles(tester, [p0.positions.last]);
    await tester.tap(find.text('Check'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, '11_feedback');
    await tester.pump(const Duration(milliseconds: 1400));
    for (var i = 1; i < 10; i++) {
      await round(tester, i, i.isEven ? 6 : 5);
      if (i == 3) {
        await until(tester, find.text('Remember'));
        await tester.pump(const Duration(milliseconds: 300));
        await shot(tester, '12_round5');
      }
    }
    await settle(tester, 2600);
    await shot(tester, '13_results');

    // Weak 8×8 session start + quit dialog + pause.
    Nav.play(tester.element(find.byType(Scaffold).first), Sessions.level(20), replace: true);
    await settle(tester);
    await until(tester, find.text('Remember'));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '14_memorize_8x8');
    await tester.binding.handlePopRoute();
    await settle(tester, 400);
    await shot(tester, '15_quit_dialog');
    await tester.tap(find.text('Continue playing'));
    await settle(tester, 400);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester, 100);
    await shot(tester, '16_paused');
    await tester.tap(find.text('Resume'));
    for (var i = 0; i < 10; i++) {
      await round(tester, i, 7);
    }
    await settle(tester, 2600);
    await shot(tester, '17_results_weak');
  });

  testWidgets('small phone', (tester) async {
    phone(tester, 320, 568);
    await boot(tester, progressPrefs());
    await settle(tester, 2000);
    await settle(tester, 1500);
    await shot(tester, '20_small_home');
    Nav.play(tester.element(find.byType(Scaffold).first), Sessions.level(25));
    await settle(tester);
    await until(tester, find.text('Remember'));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '21_small_memorize_8x8');
    await until(tester, find.text('Recreate'));
    await tester.pump(const Duration(milliseconds: 500));
    await tapTiles(tester, game(tester).spec.patterns[0].positions.take(5));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '22_small_recall_8x8');
  });

  testWidgets('tablet', (tester) async {
    phone(tester, 800, 1280);
    await boot(tester, progressPrefs());
    await settle(tester, 2000);
    await settle(tester, 1500);
    await shot(tester, '30_tablet_home');
    Nav.play(tester.element(find.byType(Scaffold).first), Sessions.level(12));
    await settle(tester);
    await until(tester, find.text('Remember'));
    await tester.pump(const Duration(milliseconds: 600));
    await shot(tester, '31_tablet_memorize');
  });
}
