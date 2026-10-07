import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/game_controller.dart';
import '../game/models/round_result.dart';
import '../game/models/tile_position.dart';
import '../game/widgets/game_timer.dart';
import '../game/widgets/score_display.dart';
import '../game/widgets/spatial_board.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import 'results_screen.dart';

/// Plays one round described by [spec].
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.spec, this.readyDelay = const Duration(milliseconds: 900)});

  final RoundSpec spec;

  /// Pause on "GET READY" before the pattern appears.
  final Duration readyDelay;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final AppState _app = AppScope.read(context);
  late final GameController _game;
  Timer? _readyTimer;
  bool _dialogOpen = false;
  bool _wakeLockOn = false;

  @override
  void initState() {
    super.initState();
    _game = GameController(widget.spec, onCountdownTick: _onCountdown);
    _game.addListener(_onGameChanged);
    WidgetsBinding.instance.addObserver(this);
    _setWakeLock(true);
    _readyTimer = Timer(widget.readyDelay, _startIfReady);
  }

  void _startIfReady() {
    if (!mounted || _game.isPaused || _dialogOpen) return;
    _game.start();
  }

  void _onCountdown(int secondsLeft) {
    if (secondsLeft <= 3) {
      _app.audio.play(SoundEffect.countdown);
      _app.haptics.countdown();
    }
  }

  void _onGameChanged() {
    if (!_game.isActive && _game.phase != GamePhase.submitted) _setWakeLock(false);
  }

  /// Keeps the screen on only while a round is in progress.
  Future<void> _setWakeLock(bool on) async {
    if (_wakeLockOn == on) return;
    _wakeLockOn = on;
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {
      // Unsupported platform or plugin unavailable (e.g. tests).
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Phone call, screen lock, app switch: freeze the round.
        _game.pause();
        _setWakeLock(false);
      case AppLifecycleState.resumed:
        // Stay paused until the player taps Resume (see overlay).
        if (_game.isActive) _setWakeLock(true);
      case AppLifecycleState.detached:
        break;
    }
  }

  void _resume() {
    _game.resume();
    if (_game.phase == GamePhase.ready) {
      _readyTimer?.cancel();
      _readyTimer = Timer(widget.readyDelay, _startIfReady);
    }
  }

  void _onTileTap(TilePosition p) {
    if (_game.toggle(p)) {
      _app.haptics.tileTap();
      _app.audio.play(SoundEffect.tileSelect);
    }
  }

  Future<void> _submit() async {
    final evaluation = _game.submit();
    if (evaluation == null) return; // Already submitted or not allowed.
    _setWakeLock(false);
    final perfect = evaluation.correctCount == evaluation.targetCount;
    if (perfect) {
      _app.haptics.success();
      _app.audio.play(SoundEffect.correct);
    } else {
      _app.haptics.error();
      _app.audio.play(SoundEffect.incorrect);
    }
    // Persist immediately so a crash or kill after this point keeps progress.
    final outcome = await _app.recordRound(widget.spec, evaluation);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    _game.showResults();
    Navigator.of(context).pushReplacement(gameRoute<void>(context, (_) => ResultsScreen(outcome: outcome)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String stay,
    required String leave,
  }) async {
    _dialogOpen = true;
    final wasPaused = _game.isPaused;
    _game.pause();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(body),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(stay)),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.wrong, minimumSize: const Size(64, 48)),
                onPressed: () => Navigator.pop(context, true),
                child: Text(leave, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return false;
    setState(() => _dialogOpen = false);
    if (result != true && !wasPaused) _resume();
    return result == true;
  }

  Future<void> _confirmQuit() async {
    final quit = await _confirm(
      title: 'QUIT GAME?',
      body: 'Your current progress will be lost.',
      stay: 'CONTINUE PLAYING',
      leave: 'QUIT',
    );
    if (quit && mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmRestart() async {
    final restart = await _confirm(
      title: 'RESTART ROUND?',
      body: widget.spec.mode == RoundMode.level
          ? 'You will get a new pattern and the timer starts again.'
          : 'The timer starts again with the same pattern.',
      stay: 'KEEP PLAYING',
      leave: 'RESTART',
    );
    if (restart && mounted) Nav.play(context, Rounds.again(widget.spec), replace: true);
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _game.removeListener(_onGameChanged);
    _game.dispose();
    _setWakeLock(false);
    super.dispose();
  }

  String get _title => switch (widget.spec.mode) {
    RoundMode.level => 'LEVEL ${widget.spec.config.level}',
    RoundMode.daily => widget.spec.officialDaily ? 'DAILY' : 'DAILY · PRACTICE',
  };

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotionOf(context, AppScope.of(context).settings.reducedMotion);
    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        final phase = _game.phase;
        return PopScope(
          canPop: !_game.isActive,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !_dialogOpen) _confirmQuit();
          },
          child: Scaffold(
            body: GameBackground(
              child: SafeArea(
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        // Short screens (small phones, big system bars) get a
                        // tighter header/footer so the board keeps large tiles.
                        final compact = box.maxHeight < 700;
                        return Column(
                          children: [
                            _TopBar(
                              title: _title,
                              streak: _app.streak,
                              onBack: () => Navigator.of(context).maybePop(),
                              onRestart: _game.isActive ? _confirmRestart : null,
                            ),
                            _PhaseHeader(phase: phase, targetCount: _game.targetCount, compact: compact),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 8),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
                                    child: AspectRatio(aspectRatio: 1, child: _board(phase, reduced)),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 104 : 170, child: _footer(phase, reduced, compact)),
                          ],
                        );
                      },
                    ),
                    if (_game.isPaused && !_dialogOpen) _PauseOverlay(onResume: _resume),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _board(GamePhase phase, bool reduced) {
    final pattern = widget.spec.pattern;
    if (phase == GamePhase.submitted || phase == GamePhase.results) {
      return SpatialBoard(
        gridSize: pattern.gridSize,
        view: BoardView.yourAnswer,
        evaluation: _game.evaluation,
        reducedMotion: reduced,
      );
    }
    return SpatialBoard(
      gridSize: pattern.gridSize,
      activeTiles: phase == GamePhase.memorizing ? pattern.positions : const {},
      selectedTiles: _game.selected,
      interactive: phase == GamePhase.recalling && !_game.isPaused,
      onTileTap: _onTileTap,
      reducedMotion: reduced,
    );
  }

  Widget _footer(GamePhase phase, bool reduced, bool compact) {
    switch (phase) {
      case GamePhase.ready:
      case GamePhase.memorizing:
      case GamePhase.transitioning:
        return Center(
          child: GameTimer(remainingMs: _game.remainingMs, reducedMotion: reduced, compact: compact),
        );
      case GamePhase.recalling:
        final count = _game.selected.length;
        final target = _game.targetCount;
        final counter = Semantics(
          liveRegion: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: compact ? 'Selected\n' : 'Selected  ',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                TextSpan(
                  text: '$count / $target',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: count > target
                        ? AppColors.wrong
                        : count == target
                        ? AppColors.correct
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            textAlign: compact ? TextAlign.left : TextAlign.center,
            style: TextStyle(fontSize: compact ? 15 : 20, fontWeight: FontWeight.w700, height: 1.15),
          ),
        );
        final warning = SizedBox(
          height: 26,
          child: Center(
            child: _game.tooManySelected
                ? Text(
                    'Select only $target tiles.',
                    style: const TextStyle(color: AppColors.wrong, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
        );
        final button = FilledButton(
          onPressed: _game.canSubmit ? _submit : null,
          child: const FittedBox(child: Text('CHECK ANSWER')),
        );
        if (compact) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                warning,
                Row(
                  children: [
                    counter,
                    const SizedBox(width: 16),
                    Expanded(child: button),
                  ],
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              counter,
              warning,
              SizedBox(width: double.infinity, child: button),
            ],
          ),
        );
      case GamePhase.submitted:
      case GamePhase.results:
        final e = _game.evaluation!;
        return Center(
          child: Text(
            '${e.correctCount} / ${e.targetCount} correct',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.streak, required this.onBack, required this.onRestart});
  final String title;
  final int streak;
  final VoidCallback onBack;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
    child: Row(
      children: [
        IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: onBack),
        IconButton(
          tooltip: 'Restart round',
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.textSecondary,
          onPressed: onRestart,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        StreakBadge(streak: streak),
      ],
    ),
  );
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.phase, required this.targetCount, required this.compact});
  final GamePhase phase;
  final int targetCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, color) = switch (phase) {
      GamePhase.ready => ('GET READY', 'Memorize the pattern.', AppColors.textSecondary),
      GamePhase.memorizing => ('REMEMBER', 'Memorize the pattern.', AppColors.active),
      GamePhase.transitioning => ('REMEMBER', 'Here it goes…', AppColors.active),
      GamePhase.recalling => ('RECREATE', 'Tap the $targetCount tiles you remember.', AppColors.selected),
      GamePhase.submitted || GamePhase.results => ('CHECKING', 'Let\'s see how you did.', AppColors.textSecondary),
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.only(top: compact ? 0 : 8),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: compact ? 24 : 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: color,
              ),
            ),
            SizedBox(height: compact ? 0 : 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: compact ? 13 : 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume});
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      // Opaque: the board can't be studied while paused.
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_filled_rounded, size: 72, color: AppColors.active),
              const SizedBox(height: 16),
              const Text('PAUSED', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 8),
              const Text(
                'The timer stopped while you were away.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 240,
                child: FilledButton(onPressed: onResume, child: const Text('RESUME')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
