import 'dart:async';

import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/logic/level_manager.dart';
import '../game/logic/scoring_engine.dart';
import '../game/models/round_result.dart';
import '../game/spatial_game.dart';
import '../game/widgets/score_display.dart';
import '../game/widgets/spatial_board.dart';
import '../services/audio_service.dart';
import '../state/app_state.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.outcome});
  final RoundOutcome outcome;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Timer? _xpTimer;

  RoundOutcome get o => widget.outcome;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    if (o.passed && o.spec.mode == RoundMode.level) {
      app.haptics.levelComplete();
      app.audio.play(SoundEffect.levelComplete);
    }
    _xpTimer = Timer(const Duration(milliseconds: 900), () => app.audio.play(SoundEffect.xpEarned));
  }

  @override
  void dispose() {
    _xpTimer?.cancel();
    super.dispose();
  }

  String get _headline {
    final acc = o.evaluation.accuracy;
    if (acc >= 100) return 'PERFECT RECALL!';
    if (acc >= 80) return 'GREAT RECALL!';
    if (o.passed) return 'NICE WORK!';
    return 'KEEP GOING';
  }

  String get _speedLabel => switch (o.score.speed) {
    SpeedRating.fast => 'FAST',
    SpeedRating.steady => 'STEADY',
    SpeedRating.relaxed => 'RELAXED',
  };

  List<String> get _messages {
    final e = o.evaluation;
    final missed = e.targetCount - e.correctCount;
    return [
      if (missed > 0) 'You missed $missed position${missed == 1 ? '' : 's'}.',
      if (o.spec.mode == RoundMode.level && !o.passed)
        'Get ${LevelManager.tilesToPass(o.spec.config)} of ${e.targetCount} to pass. You\'ve got this.',
      if (o.unlockedLevel != null) 'Level ${o.unlockedLevel} unlocked!',
      if (o.newBest) 'New best score!',
      if (o.leveledUp) 'You reached player level ${o.playerLevelAfter}!',
      if (o.spec.mode == RoundMode.daily)
        o.officialDailyRecorded
            ? 'Official daily score recorded.'
            : 'Practice round — your official daily score is unchanged.',
    ];
  }

  void _continue() {
    final nav = Navigator.of(context);
    if (o.spec.mode == RoundMode.level && o.passed && o.spec.config.level < LevelManager.levelCount) {
      Nav.levelIntro(context, o.spec.config.level + 1, replace: true);
    } else {
      nav.pop();
    }
  }

  void _tryAgain() => Nav.play(context, Rounds.again(_retrySpec()), replace: true);

  /// Retrying a daily is always practice.
  RoundSpec _retrySpec() => o.spec.mode == RoundMode.daily
      ? RoundSpec(mode: RoundMode.daily, config: o.spec.config, pattern: o.spec.pattern, dailyDate: o.spec.dailyDate)
      : o.spec;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final reduced = reduceMotionOf(context, app.settings.reducedMotion);
    final e = o.evaluation;
    final text = Theme.of(context).textTheme;
    final positive = o.passed;
    final isDaily = o.spec.mode == RoundMode.daily;

    final primary = positive || isDaily
        ? FilledButton(onPressed: _continue, child: Text(isDaily ? 'DONE' : 'CONTINUE'))
        : FilledButton(onPressed: _tryAgain, child: const Text('TRY AGAIN'));
    final secondary = positive || isDaily
        ? OutlinedButton(onPressed: _tryAgain, child: Text(isDaily ? 'PRACTICE AGAIN' : 'PLAY AGAIN'))
        : OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CONTINUE'));

    return Scaffold(
      body: GameBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _headline,
                            textAlign: TextAlign.center,
                            style: text.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: positive ? AppColors.correct : AppColors.selected,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: CountUpText(
                              value: o.score.total,
                              animate: !reduced,
                              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, height: 1.1),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(child: StarRow(stars: o.stars, size: 34)),
                          const SizedBox(height: 10),
                          Text(
                            '${e.correctCount} / ${e.targetCount} CORRECT',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _Metric(label: 'Accuracy', value: '${e.accuracy.round()}%'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _Metric(label: 'Speed', value: _speedLabel),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _XpPanel(outcome: o, animate: !reduced),
                          for (final m in _messages)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                m,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          _Comparison(outcome: o, reducedMotion: reduced),
                          const SizedBox(height: 16),
                          _Breakdown(score: o.score),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                    child: Column(
                      children: [
                        SizedBox(width: double.infinity, child: primary),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (positive && !reduced) Positioned.fill(child: CelebrationOverlay(intensity: e.accuracy / 100)),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    child: Column(
      children: [
        Caption(label),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.score});
  final ScoreBreakdown score;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int value, {bool total = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: total ? FontWeight.w900 : FontWeight.w600,
              color: total ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            total ? formatNumber(value) : '+${formatNumber(value)}',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: total ? 18 : 15),
          ),
        ],
      ),
    );
    return GameCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        children: [
          row('Base score', score.base),
          if (score.speedBonus > 0) row('Speed bonus', score.speedBonus),
          if (score.perfectBonus > 0) row('Perfect bonus', score.perfectBonus),
          if (score.streakBonus > 0) row('Streak bonus', score.streakBonus),
          const Divider(color: AppColors.outline),
          row('Total', score.total, total: true),
        ],
      ),
    );
  }
}

/// XP bar animating from the old to the new value, with a floating "+XP".
class _XpPanel extends StatelessWidget {
  const _XpPanel({required this.outcome, required this.animate});
  final RoundOutcome outcome;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    return GameCard(
      padding: const EdgeInsets.all(16),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: o.xpBefore.toDouble(), end: o.xpAfter.toDouble()),
        duration: animate ? const Duration(milliseconds: 1100) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, xp, _) {
          final (into, needed) = XpLevels.progress(xp.round());
          final level = XpLevels.levelForXp(xp.round());
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('LEVEL $level', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const Spacer(),
                  _FloatingXp(amount: o.xpGained, animate: animate),
                ],
              ),
              const SizedBox(height: 10),
              XpBar(fraction: into / needed),
              const SizedBox(height: 6),
              Text(
                '${formatNumber(into)} / ${formatNumber(needed)} XP',
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FloatingXp extends StatelessWidget {
  const _FloatingXp({required this.amount, required this.animate});
  final int amount;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      '+$amount XP',
      style: const TextStyle(color: AppColors.active, fontWeight: FontWeight.w900, fontSize: 18),
    );
    if (!animate) return label;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: label,
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.outcome, required this.reducedMotion});
  final RoundOutcome outcome;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final grid = outcome.spec.pattern.gridSize;
    Widget board(String title, BoardView view) => Expanded(
      child: Column(
        children: [
          Caption(title, align: TextAlign.center),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1,
            child: SpatialBoard.review(
              gridSize: grid,
              evaluation: outcome.evaluation,
              view: view,
              reducedMotion: reducedMotion,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            board('Your answer', BoardView.yourAnswer),
            const SizedBox(width: 12),
            board('Correct pattern', BoardView.solution),
          ],
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 16,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _Legend(color: AppColors.correct, label: 'Correct'),
            _Legend(color: AppColors.wrong, label: 'Wrong'),
            _Legend(color: AppColors.active, label: 'Missed', outlined: true),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.outlined = false});
  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: outlined ? null : color,
          borderRadius: BorderRadius.circular(4),
          border: outlined ? Border.all(color: color, width: 2) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    ],
  );
}
