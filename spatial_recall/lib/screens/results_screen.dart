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
import '../ui/components.dart';

/// Summary of a whole session: score, accuracy, promotion and a review of
/// every round.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.outcome});
  final SessionOutcome outcome;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Timer? _xpTimer;

  SessionOutcome get o => widget.outcome;
  bool get isDaily => o.spec.mode == RoundMode.daily;
  bool get isLastLevel => o.spec.config.level >= LevelManager.levelCount;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    if (o.promoted) {
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
    final acc = o.accuracy;
    if (acc >= 100) return 'Flawless!';
    if (o.promoted && acc >= 90) return 'Brilliant recall!';
    if (o.promoted) return 'Level cleared!';
    if (acc >= 60) return 'So close!';
    return 'Keep training';
  }

  String get _verdict {
    final need = o.spec.config.passPercentage;
    if (isDaily) {
      return o.officialDailyRecorded
          ? 'Official daily score recorded.'
          : 'Practice round. Your official daily score is unchanged.';
    }
    if (o.promoted) {
      if (o.unlockedLevel != null) return 'Promoted to Level ${o.unlockedLevel}!';
      return isLastLevel ? 'You have cleared every level!' : 'Level cleared again. Nice consistency.';
    }
    return 'Reach $need% accuracy to move up. You got ${o.accuracy.round()}%.';
  }

  void _continue() {
    if (!isDaily && o.promoted && !isLastLevel) {
      Nav.levelIntro(context, o.spec.config.level + 1, replace: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _again() => Nav.play(context, Sessions.again(o.spec), replace: true);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final reduced = reduceMotionOf(context, app.settings.reducedMotion);
    final positive = o.promoted || (isDaily && o.accuracy >= 80);
    final accent = positive ? AppColors.mint : AppColors.coral;

    final primaryLabel = isDaily
        ? 'Done'
        : o.promoted && !isLastLevel
        ? 'Next level'
        : o.promoted
        ? 'Done'
        : 'Try again';
    final primary = PrimaryButton(
      label: primaryLabel,
      icon: primaryLabel == 'Next level' ? Icons.arrow_forward_rounded : null,
      gradient: positive ? AppGradients.brand : AppGradients.sunrise,
      onPressed: o.promoted || isDaily ? _continue : _again,
    );
    final secondary = SecondaryButton(
      label: isDaily ? 'Practice again' : (o.promoted ? 'Play again' : 'Back to home'),
      onPressed: o.promoted || isDaily ? _again : () => Navigator.of(context).pop(),
    );

    var i = 0;
    Widget enter(Widget child) => Entrance(
      delay: Duration(milliseconds: 80 * i++),
      enabled: !reduced,
      child: child,
    );

    return Scaffold(
      body: GameBackground(
        tint: accent,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          enter(
                            Text(
                              o.spec.mode == RoundMode.level ? 'LEVEL ${o.spec.config.level}' : 'DAILY CHALLENGE',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          enter(
                            Text(
                              _headline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                            ),
                          ),
                          const SizedBox(height: 18),
                          enter(_AccuracyHero(outcome: o, animate: !reduced, accent: accent)),
                          const SizedBox(height: 16),
                          enter(
                            Text(
                              _verdict,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: positive ? AppColors.mint : AppColors.coral,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          enter(
                            Row(
                              children: [
                                Expanded(
                                  child: _Stat(
                                    label: 'Perfect rounds',
                                    value: '${o.perfectRounds}/${o.rounds.length}',
                                    icon: Icons.verified_rounded,
                                    color: AppColors.mint,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Stat(
                                    label: 'Tiles found',
                                    value: '${o.correct}/${o.target}',
                                    icon: Icons.grid_view_rounded,
                                    color: AppColors.violet,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          enter(_XpPanel(outcome: o, animate: !reduced)),
                          if (o.newBest || o.leveledUp) ...[
                            const SizedBox(height: 12),
                            enter(
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (o.newBest)
                                    const Pill(
                                      label: 'New best score',
                                      icon: Icons.emoji_events_rounded,
                                      color: AppColors.amber,
                                    ),
                                  if (o.leveledUp)
                                    Pill(
                                      label: 'Player level ${o.playerLevelAfter}',
                                      icon: Icons.trending_up_rounded,
                                      color: AppColors.violet,
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          enter(_RoundReview(outcome: o, reducedMotion: reduced)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Column(children: [primary, const SizedBox(height: 10), secondary]),
                  ),
                ],
              ),
            ),
            if (o.promoted && !reduced) Positioned.fill(child: CelebrationOverlay(intensity: o.accuracy / 100)),
          ],
        ),
      ),
    );
  }
}

/// Big ring showing session accuracy against the promotion mark, with the
/// score and stars.
class _AccuracyHero extends StatelessWidget {
  const _AccuracyHero({required this.outcome, required this.animate, required this.accent});
  final SessionOutcome outcome;
  final bool animate;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    return GameCard(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: o.accuracy / 100),
            duration: animate ? const Duration(milliseconds: 1200) : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Ring(
              progress: v,
              size: 168,
              stroke: 14,
              gradient: o.promoted ? AppGradients.mint : AppGradients.sunrise,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(v * 100).round()}%',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1),
                  ),
                  const Text(
                    'accuracy',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          StarRow(stars: o.stars, size: 30),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Score  ',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              CountUpText(
                value: o.score.total,
                animate: animate,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.violet),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ],
    ),
  );
}

/// XP bar animating from the old to the new value, with a floating "+XP".
class _XpPanel extends StatelessWidget {
  const _XpPanel({required this.outcome, required this.animate});
  final SessionOutcome outcome;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    return GameCard(
      padding: const EdgeInsets.all(18),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: o.xpBefore.toDouble(), end: o.xpAfter.toDouble()),
        duration: animate ? const Duration(milliseconds: 1300) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, xp, _) {
          final (into, needed) = XpLevels.progress(xp.round());
          final level = XpLevels.levelForXp(xp.round());
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Player level $level', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const Spacer(),
                  _FloatingXp(amount: o.xpGained, animate: animate),
                ],
              ),
              const SizedBox(height: 10),
              XpBar(fraction: into / needed),
              const SizedBox(height: 6),
              Text(
                '${formatNumber(into)} / ${formatNumber(needed)} XP',
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
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
    final label = Pill(label: '+$amount XP', icon: Icons.bolt_rounded, color: AppColors.violet, filled: true);
    if (!animate) return label;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: label,
    );
  }
}

/// Horizontal strip of every round's marked board.
class _RoundReview extends StatelessWidget {
  const _RoundReview({required this.outcome, required this.reducedMotion});
  final SessionOutcome outcome;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(left: 4, bottom: 10), child: Caption('Round review')),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: o.rounds.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final r = o.rounds[i];
              return SizedBox(
                width: 116,
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: 116,
                      child: SpatialBoard.review(
                        gridSize: o.spec.config.gridSize,
                        evaluation: r,
                        view: BoardView.yourAnswer,
                        reducedMotion: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: RoundProgress.colorFor(r.accuracy), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'R${i + 1} · ${r.correctCount}/${r.targetCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _Legend(color: AppColors.mint, label: 'Correct'),
            _Legend(color: AppColors.rose, label: 'Wrong'),
            _Legend(color: AppColors.violet, label: 'Missed', outlined: true),
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
        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ],
  );
}
