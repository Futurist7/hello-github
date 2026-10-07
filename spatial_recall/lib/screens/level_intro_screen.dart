import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/logic/level_manager.dart';
import '../game/widgets/score_display.dart';
import '../state/app_state.dart';

class LevelIntroScreen extends StatelessWidget {
  const LevelIntroScreen({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final config = LevelManager.config(level);
    final progress = state.progress.levels[level - 1];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'LEVEL $level',
                        style: text.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                      const SizedBox(height: 28),
                      _Row(label: 'Board', value: '${config.gridSize} × ${config.gridSize}'),
                      _Row(label: 'Tiles', value: '${config.tileCount}'),
                      _Row(label: 'Memory time', value: '${config.memorySeconds} seconds'),
                      _Row(
                        label: 'To pass',
                        value: '${LevelManager.tilesToPass(config)} of ${config.tileCount} correct',
                      ),
                      const SizedBox(height: 10),
                      const Caption('Difficulty'),
                      const SizedBox(height: 6),
                      StarRow(stars: config.difficulty, size: 26),
                      const SizedBox(height: 24),
                      const Caption('Best score'),
                      const SizedBox(height: 6),
                      Text(
                        progress.bestScore > 0 ? formatNumber(progress.bestScore) : '—',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.star),
                      ),
                      if (progress.stars > 0) ...[const SizedBox(height: 6), StarRow(stars: progress.stars, size: 18)],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Nav.play(context, Rounds.level(level), replace: true),
                    child: const Text('START'),
                  ),
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
  const _Row({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
    ),
    child: Row(
      children: [
        Caption(label),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    ),
  );
}
