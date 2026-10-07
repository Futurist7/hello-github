import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/logic/level_manager.dart';
import '../game/logic/scoring_engine.dart';
import '../game/widgets/score_display.dart';
import '../state/app_state.dart';
import '../ui/components.dart';
import 'home_shell.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.player;
    final (into, needed) = XpLevels.progress(p.xp);
    final stats = [
      ('Sessions played', formatNumber(p.gamesPlayed), Icons.sports_esports_rounded, AppColors.violet),
      ('Best score', formatNumber(p.bestScore), Icons.emoji_events_rounded, AppColors.amber),
      (
        'Average accuracy',
        p.gamesPlayed == 0 ? '—' : '${p.averageAccuracy.round()}%',
        Icons.track_changes_rounded,
        AppColors.mint,
      ),
      ('Current streak', '${state.streak}', Icons.local_fire_department_rounded, AppColors.streak),
      ('Longest streak', '${p.longestStreak}', Icons.whatshot_rounded, AppColors.coral),
      (
        'Levels cleared',
        '${state.progress.levelsCompleted}/${LevelManager.levelCount}',
        Icons.flag_rounded,
        AppColors.blue,
      ),
    ];

    return ListView(
      padding: EdgeInsets.only(bottom: navBarClearance(context)),
      children: [
        const TabHeader(title: 'Your stats'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              GameCard(
                gradient: AppGradients.brand,
                child: Row(
                  children: [
                    Ring(
                      progress: into / needed,
                      size: 76,
                      stroke: 8,
                      gradient: const LinearGradient(colors: [Colors.white, Colors.white]),
                      track: Colors.white.withValues(alpha: 0.25),
                      child: Text(
                        '${p.xpLevel}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Player level',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${formatNumber(into)} / ${formatNumber(needed)} XP to level ${p.xpLevel + 1}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.13),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(icon, color: color, size: 21),
                                    ),
                                    const SizedBox(height: 12),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        value,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
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
