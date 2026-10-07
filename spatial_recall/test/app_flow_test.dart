import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spatial_recall/app/app.dart';
import 'package:spatial_recall/app/routes.dart';
import 'package:spatial_recall/game/models/pattern.dart';
import 'package:spatial_recall/game/models/tile_position.dart';
import 'package:spatial_recall/screens/game_screen.dart';
import 'package:spatial_recall/screens/results_screen.dart';
import 'package:spatial_recall/services/audio_service.dart';
import 'package:spatial_recall/services/haptic_service.dart';
import 'package:spatial_recall/services/storage_service.dart';
import 'package:spatial_recall/state/app_state.dart';
import 'package:spatial_recall/ui/components.dart';

Future<AppState> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await StorageService.open();
  final state = AppState(storage: storage, audio: AudioService(), haptics: HapticService());
  await tester.pumpWidget(SpatialRecallApp(key: UniqueKey(), state: state));
  // Splash animation, then the first screen's entrance animations.
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
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
  await tester.pump(const Duration(milliseconds: 700));
}

/// Pumps in small steps until [f] matches (the game has a per-frame
/// countdown, so pumpAndSettle never settles).
Future<void> pumpUntil(WidgetTester tester, Finder f, {Duration max = const Duration(seconds: 12)}) async {
  var waited = Duration.zero;
  while (f.evaluate().isEmpty) {
    if (waited > max) throw TestFailure('Timed out waiting for $f');
    await tester.pump(const Duration(milliseconds: 100));
    waited += const Duration(milliseconds: 100);
  }
}

GameScreen gameScreen(WidgetTester tester) => tester.widget<GameScreen>(find.byType(GameScreen));

Finder tile(TilePosition t) => find.bySemanticsLabel('Row ${t.row + 1}, Column ${t.column + 1}');

Future<void> tapTiles(WidgetTester tester, Iterable<TilePosition> tiles) async {
  for (final t in tiles) {
    await tester.tap(tile(t));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

/// Tiles not in [p], to make deliberate mistakes.
List<TilePosition> wrongTiles(Pattern p, int n) => [
  for (var r = 0; r < p.gridSize; r++)
    for (var c = 0; c < p.gridSize; c++) TilePosition(r, c),
].where((t) => !p.positions.contains(t)).take(n).toList();

/// Plays round [round] of the current session: waits for recall, taps
/// [correct] right tiles plus wrong ones to fill the count, then checks.
Future<void> playRound(WidgetTester tester, int round, {int? correct}) async {
  final pattern = gameScreen(tester).spec.patterns[round];
  final right = correct ?? pattern.tileCount;
  await pumpUntil(tester, find.text('Round ${round + 1} of ${gameScreen(tester).spec.rounds}'));
  await pumpUntil(tester, find.text('Recreate'));
  await tester.pump(const Duration(milliseconds: 500)); // Board switch animation done.
  await tapTiles(tester, [...pattern.positions.take(right), ...wrongTiles(pattern, pattern.tileCount - right)]);
  await tester.tap(find.text('Check'));
  await tester.pump();
}

/// Plays every round, then waits for the results screen.
Future<void> playSession(WidgetTester tester, {int? correct}) async {
  final rounds = gameScreen(tester).spec.rounds;
  for (var i = 0; i < rounds; i++) {
    await playRound(tester, i, correct: correct);
    for (var k = 0; k < 17; k++) {
      await tester.pump(const Duration(milliseconds: 100)); // Feedback.
    }
  }
  await pumpUntil(tester, find.byType(ResultsScreen));
  await settle(tester);
  await tester.pump(const Duration(seconds: 2)); // Count-ups and entrances.
}

void main() {
  testWidgets('first launch: tutorial → level 1 session → promoted to level 2 and saved', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester);
    expect(find.text('How to play'), findsOneWidget);

    await tester.ensureVisible(find.text('Got it'));
    await tester.tap(find.text('Got it'));
    await settle(tester);
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('Get ready'), findsOneWidget);
    expect(find.text('Round 1 of 10'), findsOneWidget);

    final spec = gameScreen(tester).spec;
    expect(spec.rounds, 10);
    expect(spec.patterns.first.gridSize, 5);
    expect(spec.config.memoryMs, 5000);

    // Round 1 in detail.
    await pumpUntil(tester, find.text('Remember'));
    await pumpUntil(tester, find.text('Recreate'));
    await tester.pump(const Duration(milliseconds: 500));
    await tapTiles(tester, spec.patterns[0].positions);
    expect(find.bySemanticsLabel('Selected 3 of 3'), findsOneWidget);
    await tester.tap(find.text('Check'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Perfect!'), findsOneWidget);
    expect(find.text('3 / 3 correct'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));

    for (var i = 1; i < 10; i++) {
      await playRound(tester, i);
      await tester.pump(const Duration(milliseconds: 1700));
    }
    await pumpUntil(tester, find.byType(ResultsScreen));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Flawless!'), findsOneWidget);
    expect(find.text('Promoted to Level 2!'), findsOneWidget);
    expect(find.text('10/10'), findsOneWidget); // Perfect rounds.
    expect(find.text('ROUND REVIEW'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Progress is already persisted.
    final reloaded = StorageService(await SharedPreferences.getInstance()).loadProgress();
    expect(reloaded.levels[0].completed, isTrue);
    expect(reloaded.levels[1].unlocked, isTrue);
    expect(reloaded.player.gamesPlayed, 1);
    expect(state.tutorialSeen, isTrue);

    await tester.tap(find.text('Next level'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('Check is disabled until the right count, warns on too many; a weak session is not promoted', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('Play'));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);

    final pattern = gameScreen(tester).spec.patterns[0];
    final wrong = wrongTiles(pattern, 4);
    await pumpUntil(tester, find.text('Recreate'));
    await tester.pump(const Duration(milliseconds: 500));
    await tapTiles(tester, wrong.take(2));
    bool enabled() => tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Check')).onPressed != null;
    expect(enabled(), isFalse);
    await tapTiles(tester, [wrong[2]]);
    expect(enabled(), isTrue);
    await tapTiles(tester, [wrong[3]]);
    expect(find.text('Select only 3 tiles.'), findsOneWidget);
    expect(enabled(), isFalse);
    await tapTiles(tester, [wrong[3]]); // Deselect.
    expect(find.text('Select only 3 tiles.'), findsNothing);
    await tester.tap(find.text('Check'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Almost'), findsOneWidget);
    expect(find.text('0 / 3 correct'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));

    for (var i = 1; i < 10; i++) {
      await playRound(tester, i, correct: 2);
      await tester.pump(const Duration(milliseconds: 1700));
    }
    await pumpUntil(tester, find.byType(ResultsScreen));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    // 18 of 30 tiles = 60%.
    expect(find.text('So close!'), findsOneWidget);
    expect(find.text('Reach 80% accuracy to move up. You got 60%.'), findsOneWidget);
    expect(state.progress.levels[1].unlocked, isFalse);

    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Round 1 of 10'), findsOneWidget);
  });

  testWidgets('Android back during play asks before quitting', (tester) async {
    usePhone(tester);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('Play'));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await pumpUntil(tester, find.text('Remember'));

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Quit game?'), findsOneWidget);
    expect(find.text('Your current progress will be lost.'), findsOneWidget);

    // The round is frozen while the dialog is open.
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Remember'), findsOneWidget);

    await tester.tap(find.text('Continue playing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Quit game?'), findsNothing);
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Quit'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('Spatial Recall'), findsOneWidget);
  });

  testWidgets('backgrounding during memorisation pauses until resumed', (tester) async {
    usePhone(tester);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('Play'));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await pumpUntil(tester, find.text('Remember'));
    await tester.pump(const Duration(seconds: 2));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Remember'), findsOneWidget); // Still memorising.

    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('Paused'), findsNothing);
    // About 3 of the 5 seconds remained.
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Remember'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Recreate'), findsOneWidget);
  });

  testWidgets('daily challenge: 5 rounds, first attempt official, replay is practice', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('Daily'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Daily challenge'), findsWidgets);
    final play = find.widgetWithText(PrimaryButton, 'Play');
    await tester.ensureVisible(play);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(play);
    await settle(tester);
    expect(find.text('DAILY CHALLENGE'), findsOneWidget);

    final spec = gameScreen(tester).spec;
    expect(spec.officialDaily, isTrue);
    expect(spec.rounds, 5);
    expect(spec.patterns[0].positions, state.todaysChallenge.patterns[0].positions);
    await playSession(tester);
    expect(find.text('Official daily score recorded.'), findsOneWidget);
    final official = state.dailyRecordFor(spec.dailyDate!)!.score;

    await tester.tap(find.text('Practice again'));
    await settle(tester);
    expect(find.text('DAILY · PRACTICE'), findsOneWidget);
    final practice = gameScreen(tester).spec;
    expect(practice.officialDaily, isFalse);
    expect(practice.patterns[0].positions, spec.patterns[0].positions);
    await playSession(tester, correct: 1);
    expect(find.textContaining('Practice round'), findsOneWidget);
    expect(state.dailyRecordFor(spec.dailyDate!)!.score, official);

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Practice'), findsOneWidget);
  });

  testWidgets('narrow phone (320dp): every screen and an 8×8 round lay out without overflow', (tester) async {
    usePhone(tester, width: 320, height: 568);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    expect(tester.takeException(), isNull);

    for (final tab in ['Levels', 'Daily', 'Stats', 'Home']) {
      await tester.tap(find.text(tab));
      // The current level pulses forever, so don't wait to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);

    Nav.levelIntro(tester.element(find.byType(Scaffold).first), 20);
    await settle(tester);
    expect(find.text('Level 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Start'));
    await settle(tester);
    expect(gameScreen(tester).spec.patterns[0].gridSize, 8);

    await playRound(tester, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Perfect!'), findsOneWidget);
    // Even on this tiny screen with a tall nav bar, 8×8 tiles stay tappable.
    final cell = tester.getRect(find.bySemanticsLabel(RegExp(r'^Row 1, Column 1')).first);
    expect(cell.width, greaterThanOrEqualTo(31));
    expect(tester.takeException(), isNull);
  });

  testWidgets('typical small phone (360×640): 8×8 touch targets are ~40dp', (tester) async {
    usePhone(tester, width: 360, height: 640);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    Nav.levelIntro(tester.element(find.byType(Scaffold).first), 25);
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await pumpUntil(tester, find.text('Recreate'));
    await tester.pump(const Duration(milliseconds: 500));
    final cell = tester.getRect(find.bySemanticsLabel('Row 4, Column 4'));
    expect(cell.width, greaterThanOrEqualTo(38));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still plays a full session', (tester) async {
    usePhone(tester);
    await pumpApp(
      tester,
      prefs: {'tutorial_seen.v1': true, 'settings.v1': '{"sound": false, "haptics": false, "reducedMotion": true}'},
    );
    await tester.tap(find.text('Play'));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await playSession(tester);
    expect(find.text('Flawless!'), findsOneWidget);
  });

  testWidgets('patterns stay fixed across rebuilds; rounds advance', (tester) async {
    usePhone(tester);
    await pumpApp(tester, prefs: {'tutorial_seen.v1': true});
    await tester.tap(find.text('Play'));
    await settle(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    final before = gameScreen(tester).spec.patterns.map((p) => p.positions).toList();
    tester.view.physicalSize = const Size(400 * 3, 800 * 3);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(gameScreen(tester).spec.patterns.map((p) => p.positions).toList(), before);
    await playRound(tester, 0);
    await pumpUntil(tester, find.text('Round 2 of 10'));
    await pumpUntil(tester, find.text('Remember'));
  });
}
