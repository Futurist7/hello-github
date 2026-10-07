import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/game_controller.dart';
import '../game/logic/progression.dart';
import '../game/models/round_result.dart';
import '../game/models/tile_position.dart';
import '../game/widgets/game_timer.dart';
import '../game/widgets/score_display.dart';
import '../game/widgets/spatial_board.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';
import '../ui/components.dart';
import 'results_screen.dart';

/// Plays a whole session ([SessionSpec.rounds] rounds, 10 for a level).
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.spec,
    this.readyDelay = const Duration(milliseconds: 900),
    this.betweenRounds = const Duration(milliseconds: 450),
  });

  final SessionSpec spec;

  /// "Get ready" pause before the first round.
  final Duration readyDelay;

  /// Pause before each later round's pattern appears.
  final Duration betweenRounds;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final AppState _app = AppScope.read(context);
  late GameController _game;
  final List<RoundEvaluation> _results = [];
  int _round = 0;
  Timer? _readyTimer;
  Timer? _feedbackTimer;

  /// The previous round's controller, kept alive while its board animates out.
  GameController? _retired;
  Timer? _retireTimer;
  bool _dialogOpen = false;
  bool _wakeLockOn = false;
  bool _backgrounded = false;
  bool _pendingAdvance = false;
  bool _finishing = false;

  SessionSpec get spec => widget.spec;

  /// Leaving now would lose the session.
  bool get _inProgress => !_finishing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setWakeLock(true);
    _startRound(0, widget.readyDelay);
  }

  void _startRound(int index, Duration delay) {
    _round = index;
    _game = GameController(spec.round(index), onCountdownTick: _onCountdown);
    _readyTimer?.cancel();
    _readyTimer = Timer(delay, _startIfReady);
  }

  void _startIfReady() {
    if (!mounted || _game.isPaused || _dialogOpen || _backgrounded) return;
    _game.start();
  }

  void _onCountdown(int secondsLeft) {
    if (secondsLeft <= 3) {
      _app.audio.play(SoundEffect.countdown);
      _app.haptics.countdown();
    }
  }

  /// Keeps the screen on only while a session is in progress.
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
        _backgrounded = true;
        _game.pause();
        _setWakeLock(false);
      case AppLifecycleState.resumed:
        _backgrounded = false;
        if (_inProgress) _setWakeLock(true);
        // Stay paused until the player taps Resume (see overlay); but a
        // finished round waiting to advance can continue straight away.
        if (_pendingAdvance) _advance();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _resume() {
    _game.resume();
    if (_game.phase == GamePhase.ready) {
      _readyTimer?.cancel();
      _readyTimer = Timer(widget.betweenRounds, _startIfReady);
    }
  }

  void _onTileTap(TilePosition p) {
    if (_game.toggle(p)) {
      _app.haptics.tileTap();
      _app.audio.play(SoundEffect.tileSelect);
    }
  }

  void _submit() {
    final evaluation = _game.submit();
    if (evaluation == null) return; // Already submitted or not allowed.
    setState(() => _results.add(evaluation));
    if (evaluation.perfect) {
      _app.haptics.success();
      _app.audio.play(SoundEffect.correct);
    } else {
      _app.haptics.error();
      _app.audio.play(SoundEffect.incorrect);
    }
    // Show the marked board briefly; longer when there is something to learn.
    _feedbackTimer = Timer(Duration(milliseconds: evaluation.perfect ? 900 : 1600), _advance);
  }

  /// Next round, or finish the session after the last one.
  void _advance() {
    if (!mounted) return;
    if (_backgrounded || _dialogOpen) {
      _pendingAdvance = true;
      return;
    }
    _pendingAdvance = false;
    if (_results.length >= spec.rounds) {
      _finish();
      return;
    }
    _retireTimer?.cancel();
    _retired?.dispose();
    _retired = _game;
    setState(() => _startRound(_results.length, widget.betweenRounds));
    // Dispose after the outgoing board has animated away.
    _retireTimer = Timer(const Duration(milliseconds: 600), () {
      _retired?.dispose();
      _retired = null;
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    _setWakeLock(false);
    // Persist immediately so a crash or kill after this point keeps progress.
    final outcome = await _app.recordSession(spec, List.of(_results));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(gameRoute<void>(context, (_) => ResultsScreen(outcome: outcome)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String stay,
    required String leave,
  }) async {
    setState(() => _dialogOpen = true);
    final wasPaused = _game.isPaused;
    _game.pause();
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x66181B2C),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, a, _, child) {
        final t = Curves.easeOutCubic.transform(a.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        );
      },
      pageBuilder: (context, _, _) => _ConfirmDialog(title: title, body: body, stay: stay, leave: leave),
    );
    if (!mounted) return false;
    setState(() => _dialogOpen = false);
    if (result != true) {
      if (!wasPaused) _resume();
      if (_pendingAdvance) _advance();
    }
    return result == true;
  }

  Future<void> _confirmQuit() async {
    final quit = await _confirm(
      title: 'Quit game?',
      body: 'Your current progress will be lost.',
      stay: 'Continue playing',
      leave: 'Quit',
    );
    if (!quit || !mounted) return;
    // Release now rather than when the route finishes animating away.
    _setWakeLock(false);
    Navigator.of(context).pop();
  }

  Future<void> _confirmRestart() async {
    final restart = await _confirm(
      title: 'Restart?',
      body: spec.mode == RoundMode.level
          ? 'You will start this level again from round 1 with new patterns.'
          : 'You will start again from round 1. Restarts are practice.',
      stay: 'Keep playing',
      leave: 'Restart',
    );
    if (restart && mounted) Nav.play(context, Sessions.again(spec), replace: true);
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _feedbackTimer?.cancel();
    _retireTimer?.cancel();
    _retired?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _game.dispose();
    _setWakeLock(false);
    super.dispose();
  }

  String get _title => switch (spec.mode) {
    RoundMode.level => 'Level ${spec.config.level}',
    RoundMode.daily => spec.officialDaily ? 'Daily challenge' : 'Daily · practice',
  };

  int get _runningScore => ProgressionEngine.scoreRounds(_results).fold(0, (s, b) => s + b.total);

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotionOf(context, AppScope.of(context).settings.reducedMotion);
    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        final phase = _game.phase;
        return PopScope(
          canPop: !_inProgress,
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
                        // Short screens get a tighter header/footer so the
                        // board keeps large tiles.
                        final compact = box.maxHeight < 700;
                        return Column(
                          children: [
                            _Header(
                              title: _title,
                              round: _round,
                              rounds: spec.rounds,
                              score: _runningScore,
                              results: [for (final r in _results) r.accuracy],
                              onClose: () => Navigator.of(context).maybePop(),
                              onRestart: _inProgress ? _confirmRestart : null,
                              compact: compact,
                            ),
                            SizedBox(height: compact ? 4 : 14),
                            _PhaseHeader(
                              phase: phase,
                              targetCount: _game.targetCount,
                              evaluation: _game.evaluation,
                              compact: compact,
                              reduced: reduced,
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 10 : 16,
                                  vertical: compact ? 6 : 12,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
                                    child: AspectRatio(aspectRatio: 1, child: _animatedBoard(phase, reduced)),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 96 : 150, child: _footer(phase, reduced, compact)),
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

  /// The board slides/fades between rounds.
  Widget _animatedBoard(GamePhase phase, bool reduced) {
    final board = KeyedSubtree(key: ValueKey(_round), child: _board(phase, reduced));
    if (reduced) return board;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
      ),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.center, children: [...previous, ?current]),
      child: board,
    );
  }

  Widget _board(GamePhase phase, bool reduced) {
    final pattern = _game.spec.pattern;
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
    final Widget child;
    switch (phase) {
      case GamePhase.ready:
      case GamePhase.memorizing:
      case GamePhase.transitioning:
        child = MemoryTimer(
          key: ValueKey('timer$_round'),
          total: _game.memoryDuration,
          remaining: () => _game.liveRemainingMs,
          size: compact ? 76 : 92,
        );
      case GamePhase.recalling:
        final count = _game.selected.length;
        final target = _game.targetCount;
        child = Padding(
          key: const ValueKey('recall'),
          padding: EdgeInsets.fromLTRB(24, 0, 24, compact ? 8 : 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: compact ? 26 : 30,
                child: Center(
                  child: _game.tooManySelected
                      ? Text(
                          'Select only $target tiles.',
                          style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600),
                        )
                      : _SelectionDots(count: count, target: target),
                ),
              ),
              SizedBox(height: compact ? 4 : 8),
              PrimaryButton(
                label: 'Check',
                icon: Icons.check_rounded,
                height: compact ? 54 : 58,
                onPressed: _game.canSubmit ? _submit : null,
              ),
            ],
          ),
        );
      case GamePhase.submitted:
      case GamePhase.results:
        final e = _game.evaluation!;
        final points = ProgressionEngine.scoreRounds(_results).last.total;
        child = Center(
          key: const ValueKey('feedback'),
          child: _FeedbackBanner(evaluation: e, points: points),
        );
    }
    if (reduced) return child;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.round,
    required this.rounds,
    required this.score,
    required this.results,
    required this.onClose,
    required this.onRestart,
    required this.compact,
  });

  final bool compact;
  final String title;
  final int round;
  final int rounds;
  final int score;
  final List<double> results;
  final VoidCallback onClose;
  final VoidCallback? onRestart;

  Widget _score() => Semantics(
    label: 'Score $score',
    child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: score.toDouble()),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          formatNumber(v.round()),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.violet,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => compact ? _compact() : _regular();

  /// One row: close · title, round, progress · restart.
  Widget _compact() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
    child: Row(
      children: [
        CircleIconButton(icon: Icons.close_rounded, tooltip: 'Back', onPressed: onClose, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Round ${round + 1} of $rounds',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _score(),
                ],
              ),
              const SizedBox(height: 6),
              RoundProgress(total: rounds, current: round, results: results),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CircleIconButton(icon: Icons.refresh_rounded, tooltip: 'Restart', onPressed: onRestart, size: 40),
      ],
    ),
  );

  Widget _regular() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Column(
      children: [
        Row(
          children: [
            CircleIconButton(icon: Icons.close_rounded, tooltip: 'Back', onPressed: onClose),
            Expanded(
              child: Column(
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Round ${round + 1} of $rounds',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            CircleIconButton(icon: Icons.refresh_rounded, tooltip: 'Restart', onPressed: onRestart),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: RoundProgress(total: rounds, current: round, results: results),
            ),
            const SizedBox(width: 12),
            _score(),
          ],
        ),
      ],
    ),
  );
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({
    required this.phase,
    required this.targetCount,
    required this.evaluation,
    required this.compact,
    required this.reduced,
  });

  final GamePhase phase;
  final int targetCount;
  final RoundEvaluation? evaluation;
  final bool compact;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, color) = switch (phase) {
      GamePhase.ready => ('Get ready', 'Watch the board.', AppColors.textSecondary),
      GamePhase.memorizing => ('Remember', 'Memorize the pattern.', AppColors.violet),
      GamePhase.transitioning => ('Remember', 'Memorize the pattern.', AppColors.violet),
      GamePhase.recalling => ('Recreate', 'Tap the $targetCount tiles you remember.', AppColors.coral),
      GamePhase.submitted || GamePhase.results =>
        evaluation?.perfect ?? false
            ? ('Perfect!', 'Every tile in the right place.', AppColors.mint)
            : ('Almost', 'Outlined tiles are the ones you missed.', AppColors.amber),
    };
    final content = Column(
      key: ValueKey(title),
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 24 : 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: color,
            height: 1.1,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
    return Semantics(
      liveRegion: true,
      child: reduced
          ? content
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
              ),
              child: content,
            ),
    );
  }
}

/// One dot per tile to find; filled dots show how many are selected.
class _SelectionDots extends StatelessWidget {
  const _SelectionDots({required this.count, required this.target});
  final int count;
  final int target;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Selected $count of $target',
    child: ExcludeSemantics(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < target; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: i < count ? 12 : 10,
              height: i < count ? 12 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: i < count ? AppGradients.sunrise : null,
                color: i < count ? null : AppColors.outline,
              ),
            ),
        ],
      ),
    ),
  );
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.evaluation, required this.points});
  final RoundEvaluation evaluation;
  final int points;

  @override
  Widget build(BuildContext context) {
    final e = evaluation;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${e.correctCount} / ${e.targetCount} correct',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Pill(
          label: '+${formatNumber(points)} points',
          icon: Icons.bolt_rounded,
          color: e.perfect ? AppColors.mint : AppColors.amber,
          filled: true,
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.title, required this.body, required this.stay, required this.leave});
  final String title, body, stay, leave;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: AppShadows.lifted),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.pause_rounded, color: AppColors.coral, size: 30),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 22),
              PrimaryButton(label: stay, onPressed: () => Navigator.pop(context, false)),
              const SizedBox(height: 6),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.rose, minimumSize: const Size(120, 48)),
                onPressed: () => Navigator.pop(context, true),
                child: Text(leave, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume});
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: GameBackground(
      // Opaque: the board can't be studied while paused.
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppGradients.brand,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.glow(AppColors.violet),
                ),
                child: const Icon(Icons.pause_rounded, size: 46, color: Colors.white),
              ),
              const SizedBox(height: 22),
              const Text('Paused', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'The timer stopped while you were away.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 240,
                child: PrimaryButton(label: 'Resume', icon: Icons.play_arrow_rounded, onPressed: onResume),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
