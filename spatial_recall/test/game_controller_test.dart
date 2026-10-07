import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spatial_recall/game/game_controller.dart';
import 'package:spatial_recall/game/logic/level_manager.dart';
import 'package:spatial_recall/game/logic/pattern_generator.dart';
import 'package:spatial_recall/game/models/round_result.dart';
import 'package:spatial_recall/game/models/tile_position.dart';

RoundSpec spec() {
  final c = LevelManager.config(1); // 5×5, 3 tiles, 20s
  return RoundSpec(
    mode: RoundMode.level,
    config: c,
    pattern: generatePattern(gridSize: c.gridSize, tileCount: c.tileCount, seed: 7),
  );
}

void main() {
  test('walks the phases in order and times memorisation by elapsed time', () {
    fakeAsync((async) {
      final g = GameController(spec());
      expect(g.phase, GamePhase.ready);
      g.start();
      expect(g.phase, GamePhase.memorizing);
      async.elapse(const Duration(seconds: 19, milliseconds: 900));
      expect(g.phase, GamePhase.memorizing);
      expect(g.remainingMs.value, lessThanOrEqualTo(150));
      async.elapse(const Duration(milliseconds: 200));
      expect(g.phase, GamePhase.transitioning);
      async.elapse(const Duration(milliseconds: 300));
      expect(g.phase, GamePhase.recalling);
      g.dispose();
    });
  });

  test('ignores illegal transitions and input outside recall', () {
    fakeAsync((async) {
      final g = GameController(spec());
      expect(g.toggle(const TilePosition(0, 0)), isFalse);
      expect(g.submit(), isNull);
      g.start();
      g.start(); // Second start is ignored.
      expect(g.toggle(const TilePosition(0, 0)), isFalse);
      g.showResults(); // Not allowed from memorizing.
      expect(g.phase, GamePhase.memorizing);
      g.dispose();
    });
  });

  test('selection, submit gating and double-submit protection', () {
    fakeAsync((async) {
      final s = spec();
      final g = GameController(s)..start();
      async.elapse(const Duration(seconds: 21));
      expect(g.phase, GamePhase.recalling);
      final target = s.pattern.positions.toList();
      g.toggle(target[0]);
      g.toggle(target[1]);
      expect(g.canSubmit, isFalse);
      g.toggle(target[2]);
      expect(g.canSubmit, isTrue);
      // Over-select, then deselect.
      final extra = [
        for (var r = 0; r < 5; r++)
          for (var c = 0; c < 5; c++) TilePosition(r, c),
      ].firstWhere((t) => !s.pattern.positions.contains(t));
      g.toggle(extra);
      expect(g.tooManySelected, isTrue);
      expect(g.canSubmit, isFalse);
      g.toggle(extra);
      expect(g.canSubmit, isTrue);
      expect(g.toggle(const TilePosition(9, 9)), isFalse); // Outside the board.

      async.elapse(const Duration(seconds: 4));
      final e = g.submit();
      expect(e, isNotNull);
      expect(e!.accuracy, 100);
      expect(e.recallTime.inSeconds, 4);
      expect(g.submit(), isNull);
      expect(g.phase, GamePhase.submitted);
      g.showResults();
      expect(g.phase, GamePhase.results);
      g.dispose();
    });
  });

  test('pausing freezes the memorisation timer exactly', () {
    fakeAsync((async) {
      final g = GameController(spec())..start();
      async.elapse(const Duration(seconds: 5));
      g.pause();
      async.elapse(const Duration(minutes: 10));
      expect(g.phase, GamePhase.memorizing);
      expect(g.remainingMs.value, closeTo(15000, 100));
      g.resume();
      async.elapse(const Duration(seconds: 14));
      expect(g.phase, GamePhase.memorizing);
      async.elapse(const Duration(seconds: 2));
      expect(g.phase, isNot(GamePhase.memorizing));
      g.dispose();
    });
  });

  test('paused recall does not count toward recall time and blocks taps', () {
    fakeAsync((async) {
      final s = spec();
      final g = GameController(s)..start();
      async.elapse(const Duration(seconds: 21));
      async.elapse(const Duration(seconds: 2));
      g.pause();
      expect(g.toggle(s.pattern.positions.first), isFalse);
      async.elapse(const Duration(minutes: 5));
      g.resume();
      for (final t in s.pattern.positions) {
        g.toggle(t);
      }
      async.elapse(const Duration(seconds: 1));
      final e = g.submit()!;
      expect(e.recallTime.inSeconds, 3);
      g.dispose();
    });
  });

  test('timers stop after dispose', () {
    fakeAsync((async) {
      final g = GameController(spec())..start();
      g.dispose();
      async.elapse(const Duration(seconds: 30));
      expect(async.pendingTimers, isEmpty);
    });
  });
}
