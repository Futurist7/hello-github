import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'models/round_result.dart';
import 'models/tile_position.dart';

enum GamePhase { ready, memorizing, transitioning, recalling, submitted, results }

/// Allowed phase transitions. Anything else is ignored.
const Map<GamePhase, Set<GamePhase>> _transitions = {
  GamePhase.ready: {GamePhase.memorizing},
  GamePhase.memorizing: {GamePhase.transitioning},
  GamePhase.transitioning: {GamePhase.recalling},
  GamePhase.recalling: {GamePhase.submitted},
  GamePhase.submitted: {GamePhase.results},
  GamePhase.results: {},
};

/// Drives one round. The pattern comes from [spec] and never changes for
/// the lifetime of the controller.
///
/// Timing is measured with stopwatches (elapsed wall time) rather than by
/// counting ticks, so dropped frames or late timer callbacks don't make the
/// countdown drift. The stopwatches stop while the round is paused.
class GameController extends ChangeNotifier {
  GameController(
    this.spec, {
    this.transitionDuration = const Duration(milliseconds: 300),
    this.tickInterval = const Duration(milliseconds: 50),
    this.onCountdownTick,
  }) : remainingMs = ValueNotifier(spec.config.memoryMs);

  final RoundSpec spec;
  final Duration transitionDuration;
  final Duration tickInterval;

  /// Called when the visible whole-second countdown changes (3, 2, 1…).
  final void Function(int secondsLeft)? onCountdownTick;

  /// Remaining memorisation time. Separate from [notifyListeners] so the
  /// countdown can update without rebuilding the board.
  final ValueNotifier<int> remainingMs;

  GamePhase _phase = GamePhase.ready;
  GamePhase get phase => _phase;

  bool _paused = false;
  bool get isPaused => _paused;

  final Set<TilePosition> _selected = {};
  Set<TilePosition> get selected => Set.unmodifiable(_selected);

  final Stopwatch _memoryWatch = clock.stopwatch();
  final Stopwatch _recallWatch = clock.stopwatch();
  Timer? _ticker;
  Timer? _transitionTimer;
  int _lastShownSecond = -1;
  bool _disposed = false;

  RoundEvaluation? _evaluation;
  RoundEvaluation? get evaluation => _evaluation;

  int get targetCount => spec.pattern.tileCount;

  /// Remaining memorisation time computed right now (for per-frame
  /// animations; [remainingMs] only updates every [tickInterval]).
  int get liveRemainingMs {
    if (_phase == GamePhase.ready) return memoryDuration.inMilliseconds;
    if (_phase != GamePhase.memorizing) return 0;
    final left = memoryDuration.inMilliseconds - _memoryWatch.elapsedMilliseconds;
    return left < 0 ? 0 : left;
  }

  Duration get memoryDuration => spec.config.memoryDuration;

  bool get canSubmit => _phase == GamePhase.recalling && !_paused && _selected.length == targetCount;
  bool get tooManySelected => _selected.length > targetCount;

  /// Phases in which leaving would lose the round.
  bool get isActive =>
      _phase == GamePhase.ready ||
      _phase == GamePhase.memorizing ||
      _phase == GamePhase.transitioning ||
      _phase == GamePhase.recalling;

  bool _go(GamePhase next) {
    if (_disposed || !_transitions[_phase]!.contains(next)) return false;
    _phase = next;
    return true;
  }

  /// READY → MEMORIZING.
  void start() {
    if (!_go(GamePhase.memorizing)) return;
    _memoryWatch
      ..reset()
      ..start();
    _lastShownSecond = (spec.config.memoryMs / 1000).ceil();
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  void _tick() {
    if (_disposed || _phase != GamePhase.memorizing || _paused) return;
    final left = memoryDuration.inMilliseconds - _memoryWatch.elapsedMilliseconds;
    remainingMs.value = left < 0 ? 0 : left;
    final shown = (remainingMs.value / 1000).ceil();
    if (shown != _lastShownSecond) {
      _lastShownSecond = shown;
      if (shown > 0) onCountdownTick?.call(shown);
    }
    if (left <= 0) _beginTransition();
  }

  /// MEMORIZING → TRANSITIONING → RECALLING. Input is ignored while
  /// transitioning; the board animates the tiles away.
  void _beginTransition() {
    if (!_go(GamePhase.transitioning)) return;
    _ticker?.cancel();
    _memoryWatch.stop();
    remainingMs.value = 0;
    notifyListeners();
    _transitionTimer = Timer(transitionDuration, () {
      if (!_go(GamePhase.recalling)) return;
      _recallWatch.reset();
      if (!_paused) _recallWatch.start();
      notifyListeners();
    });
  }

  /// Toggles a tile during recall. Returns true if the board changed.
  bool toggle(TilePosition tile) {
    if (_phase != GamePhase.recalling || _paused || !tile.isInside(spec.pattern.gridSize)) {
      return false;
    }
    if (!_selected.remove(tile)) _selected.add(tile);
    notifyListeners();
    return true;
  }

  /// RECALLING → SUBMITTED. Returns null (and does nothing) if submission
  /// isn't allowed, which also guards against double taps.
  RoundEvaluation? submit() {
    if (!canSubmit || !_go(GamePhase.submitted)) return null;
    _recallWatch.stop();
    _evaluation = RoundEvaluation(
      target: spec.pattern.positions,
      selected: Set.of(_selected),
      recallTime: _recallWatch.elapsed,
    );
    notifyListeners();
    return _evaluation;
  }

  /// SUBMITTED → RESULTS.
  void showResults() {
    if (_go(GamePhase.results)) notifyListeners();
  }

  /// Freezes timers, e.g. when the app is backgrounded.
  void pause() {
    if (_paused || !isActive || _disposed) return;
    _paused = true;
    _memoryWatch.stop();
    _recallWatch.stop();
    notifyListeners();
  }

  /// Continues exactly where the round was paused.
  void resume() {
    if (!_paused || _disposed) return;
    _paused = false;
    if (_phase == GamePhase.memorizing) _memoryWatch.start();
    if (_phase == GamePhase.recalling) _recallWatch.start();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _transitionTimer?.cancel();
    remainingMs.dispose();
    super.dispose();
  }
}
