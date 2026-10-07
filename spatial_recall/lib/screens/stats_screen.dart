import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/logic/level_manager.dart';
import '../game/logic/scoring_engine.dart';
import '../game/widgets/score_display.dart';
import '../state/app_state.dart';
import 'home_shell.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.player;
    final (into, needed) = XpLevels.progress(p.xp);
    final stats = [
      ('Games played', formatNumber(p.gamesPlayed), Icons.sports_esports_rounded, AppColors.active),
      ('Best score', formatNumber(p.bestScore), Icons.emoji_events_rounded, AppColors.star),
      (
        'Average accuracy',
        p.gamesPlayed == 0 ? '—' : '${p.averageAccuracy.round()}%',
        Icons.track_changes_rounded,
        AppColors.correct,
      ),
      ('Current streak', '${state.streak}', Icons.local_fire_department_rounded, AppColors.streak),
      ('Longest streak', '${p.longestStreak}', Icons.whatshot_rounded, AppColors.selected),
      (
        'Levels completed',
        '${state.progress.levelsCompleted} / ${LevelManager.levelCount}',
        Icons.flag_rounded,
        AppColors.activeDeep,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const TabHeader(title: 'YOUR STATS'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              GameCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Caption('Player level'),
                    const SizedBox(height: 6),
                    Text('LEVEL ${p.xpLevel}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    XpBar(fraction: into / needed),
                    const SizedBox(height: 8),
                    Text(
                      '${formatNumber(into)} / ${formatNumber(needed)} XP',
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, box) {
                  final w = (box.maxWidth - 14) / 2;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final (label, value, icon, color) in stats)
                        SizedBox(
                          width: w,
                          child: Semantics(
                            label: '$label: $value',
                            child: ExcludeSemantics(
                              child: GameCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(icon, color: color),
                                    const SizedBox(height: 10),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        value,
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
