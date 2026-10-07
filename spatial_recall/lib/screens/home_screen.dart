import 'dart:async';

import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/logic/scoring_engine.dart';
import '../game/widgets/score_display.dart';
import '../state/app_state.dart';
import 'home_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenDaily});
  final VoidCallback onOpenDaily;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final progress = state.progress;
    final player = state.player;
    final text = Theme.of(context).textTheme;
    final level = progress.currentLevel;
    final started = player.gamesPlayed > 0;
    final (into, needed) = XpLevels.progress(player.xp);
    final challenge = state.todaysChallenge;
    final dailyDone = state.dailyRecordFor(challenge.key) != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'SPATIAL\nRECALL',
                  style: text.displaySmall?.copyWith(fontWeight: FontWeight.w900, height: 0.95, letterSpacing: 3),
                ),
              ),
            ),
            const SettingsButton(),
          ],
        ),
        const SizedBox(height: 10),
        Text('Train your spatial memory.', style: text.titleMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 28),
        const Center(child: _AmbientLogo()),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Nav.levelIntro(context, level),
          child: Text(
            progress.allLevelsCompleted
                ? 'PLAY LEVEL $level'
                : started
                ? 'CONTINUE'
                : 'PLAY',
          ),
        ),
        const SizedBox(height: 20),
        GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Level $level', style: text.titleLarge),
                  const Spacer(),
                  StreakBadge(streak: state.streak),
                ],
              ),
              const SizedBox(height: 14),
              XpBar(fraction: into / needed),
              const SizedBox(height: 8),
              Text(
                'Player level ${player.xpLevel}  ·  ${formatNumber(into)} / ${formatNumber(needed)} XP',
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
                color: AppColors.star,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Caption("Today's challenge", color: AppColors.active),
              const SizedBox(height: 10),
              Text(
                '${challenge.config.gridSize} × ${challenge.config.gridSize}',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${challenge.config.tileCount} tiles  ·  ${challenge.config.memorySeconds} seconds',
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: dailyDone ? onOpenDaily : () => Nav.playDaily(context),
                  child: Text(dailyDone ? 'VIEW DAILY RESULT' : 'PLAY DAILY'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        Caption(label),
      ],
    ),
  );
}

/// The logo with tiles slowly cycling, giving the home screen some life.
class _AmbientLogo extends StatefulWidget {
  const _AmbientLogo();

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = reduceMotionOf(context, AppScope.of(context).settings.reducedMotion);
    if (reduced) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % _frames.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: LogoMark(size: 120, lit: _frames[_frame]));
}
