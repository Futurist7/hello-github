import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spatial_recall/app/app.dart';
import 'package:spatial_recall/app/routes.dart';
import 'package:spatial_recall/game/game_controller.dart';
import 'package:spatial_recall/game/models/tile_position.dart';
import 'package:spatial_recall/screens/game_screen.dart';
import 'package:spatial_recall/screens/results_screen.dart';
import 'package:spatial_recall/services/audio_service.dart';
import 'package:spatial_recall/services/haptic_service.dart';
import 'package:spatial_recall/services/storage_service.dart';
import 'package:spatial_recall/state/app_state.dart';

Future<AppState> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await StorageService.open();
  final state = AppState(storage: storage, audio: AudioService(), haptics: HapticService());
  await tester.pumpWidget(SpatialRecallApp(state: state));
  // Splash animation.
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
  return state;
}

void usePhone(WidgetTester tester, {double width = 360, double height = 780}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, height * 3);
  // Simulate status/nav bars so SafeArea is exercised.
  tester.view.padding = const FakeViewPadding(top: 24 * 3, bottom: 48 * 3);
  addTearDown(tester.view.reset);
}

/// Lets a pushed route get past its first (offstage) frame and transition in.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

GameScreen gameScreen(WidgetTester tester) => tester.widget<GameScreen>(find.byType(GameScreen));

/// Plays the current round to the recall phase and taps [tiles].
Future<void> playRound(WidgetTester tester, {required Iterable<TilePosition> tiles}) async {
  final spec = gameScreen(tester).spec;
  await tester.pump(const Duration(milliseconds: 950)); // GET READY
  expect(find.text('REMEMBER'), findsOneWidget);
  await tester.pump(Duration(seconds: spec.config.memorySeconds, milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400)); // Board clears.
  expect(find.text('RECREATE'), findsOneWidget);
  for (final t in tiles) {
    await tester.tap(find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}'));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> submitAndShowResults(WidgetTester tester) async {
  await tester.tap(find.text('CHECK ANSWER'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await settle(tester); // Route transition.
  await tester.pump(const Duration(seconds: 2)); // Count-up / XP animations.
}

void main() {
  testWidgets('first launch: tutorial → level 1 → perfect round → level 2 unlocked and saved', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester);
    expect(find.text('HOW TO PLAY'), findsOneWidget);

    await tester.ensureVisible(find.text('GOT IT'));
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('GET READY'), findsOneWidget);

    final spec = gameScreen(tester).spec;
    expect(spec.pattern.gridSize, 5);
    expect(spec.pattern.tileCount, 3);
    await playRound(tester, tiles: spec.pattern.positions);
    expect(find.textContaining('3 / 3', findRichText: true), findsOneWidget);

    await submitAndShowResults(tester);
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('PERFECT RECALL!'), findsOneWidget);
    expect(find.text('3 / 3 CORRECT'), findsOneWidget);
    expect(find.text('Level 2 unlocked!'), findsOneWidget);
    expect(find.text('YOUR ANSWER'), findsOneWidget);
    expect(find.text('CORRECT PATTERN'), findsOneWidget);

    // Progress is already persisted.
    final reloaded = StorageService(await SharedPreferences.getInstance()).loadProgress();
    expect(reloaded.levels[0].completed, isTrue);
    expect(reloaded.levels[1].unlocked, isTrue);
    expect(reloaded.player.gamesPlayed, 1);
    expect(state.tutorialSeen, isTrue);

    await tester.tap(find.text('CONTINUE'));
    await settle(tester);
    expect(find.text('LEVEL 2'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('submit is disabled until the right count, warns on too many', (tester) async {
    usePhone(tester);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await settle(tester);

    final spec = gameScreen(tester).spec;
    final wrong = [
      for (var r = 0; r < 5; r++)
        for (var c = 0; c < 5; c++) TilePosition(r, c),
    ].where((t) => !spec.pattern.positions.contains(t)).take(4).toList();

    await playRound(tester, tiles: wrong.take(2));
    FilledButton button() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'CHECK ANSWER'));
    expect(button().onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('Row ${wrong[2].row + 1}, Column ${wrong[2].column + 1}'));
    await tester.pump();
    expect(button().onPressed, isNotNull);
    await tester.tap(find.bySemanticsLabel('Row ${wrong[3].row + 1}, Column ${wrong[3].column + 1}'));
    await tester.pump();
    expect(find.text('Select only 3 tiles.'), findsOneWidget);
    expect(button().onPressed, isNull);
    // Deselect.
    await tester.tap(find.bySemanticsLabel('Row ${wrong[3].row + 1}, Column ${wrong[3].column + 1}'));
    await tester.pump();
    expect(find.text('Select only 3 tiles.'), findsNothing);

    await submitAndShowResults(tester);
    expect(find.text('KEEP GOING'), findsOneWidget);
    expect(find.text('0 / 3 CORRECT'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('You missed 3 positions.'), findsOneWidget);

    await tester.tap(find.text('TRY AGAIN'));
    await settle(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('LEVEL 1'), findsOneWidget);
  });

  testWidgets('Android back during play asks before quitting', (tester) async {
    usePhone(tester);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('REMEMBER'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('QUIT GAME?'), findsOneWidget);
    expect(find.text('Your current progress will be lost.'), findsOneWidget);

    // The round is frozen while the dialog is open.
    final controllerTimeBefore = find.text('REMEMBER');
    await tester.pump(const Duration(seconds: 30));
    expect(controllerTimeBefore, findsOneWidget);

    await tester.tap(find.text('CONTINUE PLAYING'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('QUIT GAME?'), findsNothing);
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('QUIT'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('SPATIAL\nRECALL'), findsOneWidget);
  });

  testWidgets('backgrounding during memorisation pauses until resumed', (tester) async {
    usePhone(tester);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(seconds: 5));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('REMEMBER'), findsOneWidget); // Still memorising.

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(find.text('PAUSED'), findsNothing);
    // ~14s of the 20s remained.
    await tester.pump(const Duration(seconds: 13));
    expect(find.text('REMEMBER'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('RECREATE'), findsOneWidget);
  });

  testWidgets('daily challenge: first attempt is official, replay is practice', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    expect(find.text("TODAY'S CHALLENGE"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'PLAY'));
    await settle(tester);
    expect(find.text('DAILY'), findsOneWidget);

    final spec = gameScreen(tester).spec;
    expect(spec.officialDaily, isTrue);
    expect(spec.pattern.positions, state.todaysChallenge.pattern.positions);
    await playRound(tester, tiles: spec.pattern.positions);
    await submitAndShowResults(tester);
    expect(find.text('Official daily score recorded.'), findsOneWidget);
    final official = state.dailyRecordFor(spec.dailyDate!)!.score;

    await tester.tap(find.text('PRACTICE AGAIN'));
    await settle(tester);
    expect(find.text('DAILY · PRACTICE'), findsOneWidget);
    final practice = gameScreen(tester).spec;
    expect(practice.officialDaily, isFalse);
    expect(practice.pattern.positions, spec.pattern.positions);
    await playRound(tester, tiles: practice.pattern.positions.take(1));
    final rest = [
      for (var r = 0; r < practice.pattern.gridSize; r++)
        for (var c = 0; c < practice.pattern.gridSize; c++) TilePosition(r, c),
    ].where((t) => !practice.pattern.positions.contains(t)).take(practice.pattern.tileCount - 1);
    for (final t in rest) {
      await tester.tap(find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}'));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await submitAndShowResults(tester);
    expect(find.textContaining('Practice round'), findsOneWidget);
    expect(state.dailyRecordFor(spec.dailyDate!)!.score, official);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('PRACTICE'), findsOneWidget);
  });

  testWidgets('narrow phone (320dp): every screen and an 8×8 round lay out without overflow', (tester) async {
    usePhone(tester, width: 320, height: 568);
    final state = await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    expect(tester.takeException(), isNull);

    for (final tab in ['Levels', 'Daily', 'Stats', 'Home']) {
      await tester.tap(find.text(tab));
      // The current level pulses forever, so don't wait to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Jump straight into level 20 (8×8).
    final ctx = tester.element(find.byType(Scaffold).first);
    Nav.levelIntro(ctx, 20);
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 20'), findsOneWidget);
    await tester.tap(find.text('START'));
    await settle(tester);
    final spec = gameScreen(tester).spec;
    expect(spec.pattern.gridSize, 8);

    // Even on this tiny screen with a tall nav bar, 8×8 tiles stay tappable.
    final tileRect = tester.getRect(find.bySemanticsLabel(RegExp(r'^Row 1, Column 1')));
    expect(tileRect.width, greaterThanOrEqualTo(32));

    await playRound(tester, tiles: spec.pattern.positions);
    final cell = tester.getRect(find.bySemanticsLabel('Row 1, Column 1'));
    expect(cell.width, greaterThanOrEqualTo(32));
    await submitAndShowResults(tester);
    expect(find.text('PERFECT RECALL!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(state.progress.levels[19].completed, isTrue);
  });

  testWidgets('typical small phone (360×640): 8×8 touch targets are ~40dp+', (tester) async {
    usePhone(tester, width: 360, height: 640);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    final ctx = tester.element(find.byType(Scaffold).first);
    Nav.levelIntro(ctx, 25);
    await settle(tester);
    await tester.tap(find.text('START'));
    await settle(tester);
    final spec = gameScreen(tester).spec;
    await playRound(tester, tiles: spec.pattern.positions.take(3));
    final cell = tester.getRect(find.bySemanticsLabel('Row 4, Column 4'));
    expect(cell.width, greaterThanOrEqualTo(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still plays a full round', (tester) async {
    usePhone(tester);
    await pumpApp(
      tester,
      prefs: {'tutorial_seen.v1': true, 'settings.v1': '{"sound": false, "haptics": false, "reducedMotion": true}'},
    );
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await settle(tester);
    final spec = gameScreen(tester).spec;
    await playRound(tester, tiles: spec.pattern.positions);
    await submitAndShowResults(tester);
    expect(find.text('PERFECT RECALL!'), findsOneWidget);
  });

  testWidgets('game phases never skip: the pattern stays fixed across rebuilds', (tester) async {
    usePhone(tester);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('PLAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await settle(tester);
    final before = gameScreen(tester).spec.pattern.positions;
    // Force rebuilds (e.g. metrics change).
    tester.view.physicalSize = const Size(400 * 3, 800 * 3);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(gameScreen(tester).spec.pattern.positions, before);
    expect(find.text('REMEMBER'), findsOneWidget);
    expect(GamePhase.values.length, 6);
  });
}
