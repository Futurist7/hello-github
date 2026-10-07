import 'dart:async';

import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/logic/level_manager.dart';
import '../game/logic/scoring_engine.dart';
import '../game/widgets/score_display.dart';
import '../state/app_state.dart';
import '../ui/components.dart';
import 'home_shell.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenDaily});
  final VoidCallback onOpenDaily;

  static String greeting(DateTime now) => now.hour < 12
      ? 'Good morning'
      : now.hour < 18
      ? 'Good afternoon'
      : 'Good evening';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final reduced = reduceMotionOf(context, state.settings.reducedMotion);
    final progress = state.progress;
    final player = state.player;
    final level = progress.currentLevel;
    final config = LevelManager.config(level);
    final levelProgress = progress.levels[level - 1];
    final started = player.gamesPlayed > 0;
    final (into, needed) = XpLevels.progress(player.xp);
    final challenge = state.todaysChallenge;
    final dailyRecord = state.dailyRecordFor(challenge.key);

    var i = 0;
    Widget enter(Widget child) => Entrance(
      delay: Duration(milliseconds: 70 * i++),
      enabled: !reduced,
      child: child,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, navBarClearance(context)),
      children: [
        enter(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting(state.now),
                      style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Spatial Recall',
                        maxLines: 1,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
              StreakBadge(streak: state.streak),
              const SizedBox(width: 10),
              const SettingsButton(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        enter(
          _HeroCard(
            level: level,
            subtitle: '${config.rounds} rounds · ${config.gridSize}×${config.gridSize} · ${config.memoryLabel}',
            stars: levelProgress.stars,
            cta: progress.allLevelsCompleted
                ? 'Play level $level'
                : started
                ? 'Continue'
                : 'Play',
            onPlay: () => Nav.levelIntro(context, level),
            reduced: reduced,
          ),
        ),
        const SizedBox(height: 16),
        enter(
          Pressable(
            onTap: dailyRecord == null ? () => Nav.playDaily(context) : onOpenDaily,
            semanticLabel: dailyRecord == null ? 'Play daily challenge' : 'View daily result',
            child: GameCard(
              gradient: AppGradients.sunrise,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily challenge',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          dailyRecord == null
                              ? '${_months[challenge.date.month - 1]} ${challenge.date.day} · ${challenge.config.rounds} rounds'
                              : 'Done today · ${formatNumber(dailyRecord.score)} pts',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(
                      dailyRecord == null ? Icons.play_arrow_rounded : Icons.check_rounded,
                      color: AppColors.coral,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        enter(
          GameCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Player level ${player.xpLevel}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${formatNumber(into)} / ${formatNumber(needed)} XP',
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                XpBar(fraction: into / needed),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        enter(
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Day streak',
                  value: '${state.streak}',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.streak,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _MiniStat(
                  label: 'Best score',
                  value: formatNumber(player.bestScore),
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.level,
    required this.subtitle,
    required this.stars,
    required this.cta,
    required this.onPlay,
    required this.reduced,
  });

  final int level;
  final String subtitle;
  final int stars;
  final String cta;
  final VoidCallback onPlay;
  final bool reduced;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: AppGradients.brand,
      borderRadius: BorderRadius.circular(30),
      boxShadow: AppShadows.glow(AppColors.violet, strength: 0.4),
    ),
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'TODAY\'S TRAINING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Level $level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _AmbientLogo(reduced: reduced),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                Icons.star_rounded,
                size: 20,
                color: i < stars ? AppColors.star : Colors.white.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Pressable(
          onTap: onPlay,
          semanticLabel: cta,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(27),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cta,
                    style: const TextStyle(color: AppColors.violet, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.play_arrow_rounded, color: AppColors.violet),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

/// The logo with tiles slowly cycling, giving the hero card some life.
class _AmbientLogo extends StatefulWidget {
  const _AmbientLogo({required this.reduced});
  final bool reduced;

  @override
  State<_AmbientLogo> createState() => _AmbientLogoState();
}

class _AmbientLogoState extends State<_AmbientLogo> {
  static const _frames = [
    {1, 10},
    {6, 13},
    {3, 8},
    {0, 14},
    {5, 11},
  ];
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_AmbientLogo old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.reduced) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 1600), (_) {
        if (mounted && TickerMode.valuesOf(context).enabled) setState(() => _frame = (_frame + 1) % _frames.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: LogoMark(size: 84, lit: _frames[_frame], onDark: true));
}
