import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/logic/level_manager.dart';
import '../game/widgets/score_display.dart';
import '../state/app_state.dart';
import '../ui/components.dart';

class LevelIntroScreen extends StatelessWidget {
  const LevelIntroScreen({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final reduced = reduceMotionOf(context, state.settings.reducedMotion);
    final config = LevelManager.config(level);
    final progress = state.progress.levels[level - 1];

    var i = 0;
    Widget enter(Widget child) => Entrance(
      delay: Duration(milliseconds: 60 * i++),
      enabled: !reduced,
      child: child,
    );

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      enter(
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: AppGradients.brand,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: AppShadows.glow(AppColors.violet),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$level',
                            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      enter(
                        Text(
                          'Level $level',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      enter(StarRow(stars: config.difficulty, size: 22)),
                      const SizedBox(height: 4),
                      enter(
                        const Text(
                          'Difficulty',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 24),
                      enter(
                        GameCard(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: Column(
                            children: [
                              _Row(icon: Icons.repeat_rounded, label: 'Rounds', value: '${config.rounds}'),
                              _Row(
                                icon: Icons.grid_view_rounded,
                                label: 'Board',
                                value: '${config.gridSize} × ${config.gridSize}',
                              ),
                              _Row(icon: Icons.apps_rounded, label: 'Tiles', value: '${config.tileCount}'),
                              _Row(icon: Icons.timer_rounded, label: 'Memory time', value: config.memoryLabel),
                              _Row(
                                icon: Icons.trending_up_rounded,
                                label: 'To move up',
                                value: '${config.passPercentage}% accuracy',
                                last: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (progress.bestScore > 0)
                        enter(
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.emoji_events_rounded, color: AppColors.amber, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Best ${formatNumber(progress.bestScore)} · ${progress.bestAccuracy.round()}%',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: PrimaryButton(
                  label: 'Start',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => Nav.play(context, Sessions.level(level), replace: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, this.last = false});
  final IconData icon;
  final String label, value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: AppColors.surfaceSoft, width: 1.5)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.violet),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 15),
        ),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
