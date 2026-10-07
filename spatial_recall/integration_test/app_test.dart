// On-device test: runs the real app with real Android plugins
// (SharedPreferences, haptics, system sounds, wake lock).
//   flutter test integration_test -d <device>
// On slow/software emulators use profile mode (see README).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spatial_recall/app/app.dart';
import 'package:spatial_recall/app/routes.dart';
import 'package:spatial_recall/game/models/tile_position.dart';
import 'package:spatial_recall/screens/game_screen.dart';
import 'package:spatial_recall/screens/results_screen.dart';
import 'package:spatial_recall/services/audio_service.dart';
import 'package:spatial_recall/services/haptic_service.dart';
import 'package:spatial_recall/services/storage_service.dart';
import 'package:spatial_recall/state/app_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> launch(WidgetTester tester) async {
  final storage = await StorageService.open();
  final state = AppState(storage: storage, audio: AudioService(), haptics: HapticService());
  await tester.pumpWidget(SpatialRecallApp(key: UniqueKey(), state: state));
  await waitFor(tester, find.byType(Scaffold));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> waitFor(WidgetTester tester, Finder f, {Duration timeout = const Duration(seconds: 40)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}

Future<void> expectWakelock(WidgetTester tester, bool on) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (await WakelockPlus.enabled != on && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(await WakelockPlus.enabled, on);
}

Future<void> tapTile(WidgetTester tester, TilePosition t) async {
  await tester.tap(find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}'));
  await tester.pump(const Duration(milliseconds: 80));
}

GameScreen game(WidgetTester tester) => tester.widget<GameScreen>(find.byType(GameScreen));

/// Plays round [i] perfectly.
Future<void> playRound(WidgetTester tester, int i) async {
  final spec = game(tester).spec;
  await waitFor(tester, find.text('Round ${i + 1} of ${spec.rounds}'));
  await waitFor(tester, find.text('Recreate'));
  await tester.pump(const Duration(milliseconds: 600));
  for (final t in spec.patterns[i].positions) {
    await tapTile(tester, t);
  }
  await tester.tap(find.text('Check'));
  await waitFor(tester, find.text('Perfect!'));
}

Future<void> quitToHome(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await waitFor(tester, find.text('Quit game?'));
  await tester.tap(find.text('Quit'));
  await waitFor(tester, find.text('Spatial Recall'));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('real device: tutorial, full level session, persistence, back button, 8×8, wake lock', (tester) async {
    (await SharedPreferences.getInstance()).clear();
    await launch(tester);

    expect(find.text('How to play'), findsOneWidget);
    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it'));
    await waitFor(tester, find.byType(GameScreen));
    expect(find.text('LEVEL 1'), findsOneWidget);
    await waitFor(tester, find.text('Remember'));
    await expectWakelock(tester, true);

    // A full 10-round session, all perfect.
    for (var i = 0; i < 10; i++) {
      await playRound(tester, i);
    }
    await waitFor(tester, find.byType(ResultsScreen));
    await waitFor(tester, find.text('Promoted to Level 2!'));
    await expectWakelock(tester, false);

    // Data is on disk: a fresh storage instance (as after a restart) sees it.
    final reloaded = StorageService(await SharedPreferences.getInstance()).loadProgress();
    expect(reloaded.levels[0].completed, isTrue);
    expect(reloaded.levels[1].unlocked, isTrue);
    expect(reloaded.player.gamesPlayed, 1);

    // Restart the app UI from storage: no tutorial, progress kept.
    await launch(tester);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);

    // Level 2: Android back during play asks before quitting.
    await tester.tap(find.text('Continue'));
    await waitFor(tester, find.text('Start'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Start'));
    await waitFor(tester, find.text('Remember'));
    await tester.binding.handlePopRoute();
    await waitFor(tester, find.text('Quit game?'));
    await tester.tap(find.text('Continue playing'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GameScreen), findsOneWidget);
    await quitToHome(tester);
    await expectWakelock(tester, false);

    // Level 20: an 8×8 board with comfortable tiles on this phone.
    Nav.play(tester.element(find.byType(Scaffold).first), Sessions.level(20));
    await waitFor(tester, find.byType(GameScreen));
    expect(game(tester).spec.patterns[0].gridSize, 8);
    expect(game(tester).spec.config.memoryMs, lessThanOrEqualTo(5000));
    await playRound(tester, 0);
    final cell = tester.getRect(find.bySemanticsLabel(RegExp(r'^Row 1, Column 1')).first);
    expect(cell.width, greaterThanOrEqualTo(40));
    await waitFor(tester, find.text('Round 2 of 10'));
    await quitToHome(tester);
  });
}
