// On-device test: runs the real app with real Android plugins
// (SharedPreferences, haptics, system sounds, wake lock).
//   flutter test integration_test -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spatial_recall/app/app.dart';
import 'package:spatial_recall/app/routes.dart';
import 'package:spatial_recall/game/models/tile_position.dart';
import 'package:spatial_recall/screens/game_screen.dart';
import 'package:spatial_recall/services/audio_service.dart';
import 'package:spatial_recall/services/haptic_service.dart';
import 'package:spatial_recall/services/storage_service.dart';
import 'package:spatial_recall/state/app_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> launch(WidgetTester tester) async {
  final storage = await StorageService.open();
  final state = AppState(storage: storage, audio: AudioService(), haptics: HapticService());
  await tester.pumpWidget(SpatialRecallApp(key: UniqueKey(), state: state));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> waitFor(WidgetTester tester, Finder f, {Duration timeout = const Duration(seconds: 40)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}

Future<void> tapTile(WidgetTester tester, TilePosition t) async {
  await tester.tap(find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}'));
  await tester.pump(const Duration(milliseconds: 80));
}

/// Opens [level] from the intro screen and plays a perfect round.
Future<void> playPerfectLevel(WidgetTester tester, int level, int grid) async {
  Nav.levelIntro(tester.element(find.byType(Scaffold).first), level);
  await waitFor(tester, find.text('START'));
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('LEVEL $level'), findsOneWidget);
  await tester.tap(find.text('START'));
  await waitFor(tester, find.text('REMEMBER'));
  final spec = tester.widget<GameScreen>(find.byType(GameScreen)).spec;
  expect(spec.pattern.gridSize, grid);
  // Every tile is big enough to tap on this phone.
  final cell = tester.getRect(find.bySemanticsLabel(RegExp(r'^Row 1, Column 1')));
  expect(cell.width, greaterThanOrEqualTo(40));
  await waitFor(tester, find.text('RECREATE'), timeout: const Duration(seconds: 30));
  for (final t in spec.pattern.positions) {
    await tapTile(tester, t);
  }
  await tester.tap(find.text('CHECK ANSWER'));
  await waitFor(tester, find.text('PERFECT RECALL!'));
  expect(find.text('${spec.pattern.tileCount} / ${spec.pattern.tileCount} CORRECT'), findsOneWidget);
  await tester.tap(find.text('PLAY AGAIN'));
  await waitFor(tester, find.text('REMEMBER'));
  await tester.binding.handlePopRoute();
  await waitFor(tester, find.text('QUIT'));
  await tester.tap(find.text('QUIT'));
  await waitFor(tester, find.text('SPATIAL\nRECALL'));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('real device: tutorial, level 1, persistence, back button, wake lock', (tester) async {
    (await SharedPreferences.getInstance()).clear();
    await launch(tester);

    expect(find.text('HOW TO PLAY'), findsOneWidget);
    await tester.ensureVisible(find.text('GOT IT'));
    await tester.tap(find.text('GOT IT'));
    // Wait for the game screen itself: on slow devices the 0.9s "GET READY"
    // label can come and go between two polls.
    await waitFor(tester, find.byType(GameScreen));
    expect(find.text('LEVEL 1'), findsOneWidget);

    await waitFor(tester, find.text('REMEMBER'));
    expect(await WakelockPlus.enabled, isTrue, reason: 'screen kept awake during play');

    final spec = tester.widget<GameScreen>(find.byType(GameScreen)).spec;
    await waitFor(tester, find.text('RECREATE'), timeout: const Duration(seconds: 30));
    for (final t in spec.pattern.positions) {
      await tapTile(tester, t);
    }
    await tester.tap(find.text('CHECK ANSWER'));
    await waitFor(tester, find.text('PERFECT RECALL!'));
    expect(await WakelockPlus.enabled, isFalse, reason: 'wake lock released after the round');
    expect(find.text('Level 2 unlocked!'), findsOneWidget);

    // Data is on disk: a fresh storage instance (as after an app restart) sees it.
    final reloaded = StorageService(await SharedPreferences.getInstance()).loadProgress();
    expect(reloaded.levels[1].unlocked, isTrue);
    expect(reloaded.player.gamesPlayed, 1);

    // Restart the app UI from storage: no tutorial, progress kept.
    await launch(tester);
    expect(find.text('CONTINUE'), findsOneWidget);
    await tester.tap(find.text('Stats'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('1 / 30'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 600));

    // Level 2: Android back during play asks before quitting.
    await tester.tap(find.text('CONTINUE'));
    await waitFor(tester, find.text('START'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('START'));
    await waitFor(tester, find.text('REMEMBER'));
    await tester.binding.handlePopRoute();
    await waitFor(tester, find.text('QUIT GAME?'));
    await tester.tap(find.text('CONTINUE PLAYING'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await waitFor(tester, find.text('QUIT'));
    await tester.tap(find.text('QUIT'));
    await waitFor(tester, find.text('SPATIAL\nRECALL'));
    expect(await WakelockPlus.enabled, isFalse);

    // Level 10 (6×6, 11 tiles) and level 20 (8×8, 17 tiles).
    await playPerfectLevel(tester, 10, 6);
    await playPerfectLevel(tester, 20, 8);
    final saved = StorageService(await SharedPreferences.getInstance()).loadProgress();
    expect(saved.levels[9].completed, isTrue);
    expect(saved.levels[19].completed, isTrue);
  });
}
