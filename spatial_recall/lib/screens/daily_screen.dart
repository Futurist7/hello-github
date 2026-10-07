import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/widgets/score_display.dart';
import '../game/widgets/spatial_board.dart';
import '../state/app_state.dart';
import '../ui/components.dart';
import 'home_shell.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final challenge = state.todaysChallenge;
    final record = state.dailyRecordFor(challenge.key);
    final c = challenge.config;

    return ListView(
      padding: EdgeInsets.only(bottom: navBarClearance(context)),
      children: [
        TabHeader(title: 'Daily challenge', subtitle: '${_months[challenge.date.month - 1]} ${challenge.date.day}'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              GameCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 116,
                      // The patterns stay hidden until you play.
                      child: SpatialBoard(gridSize: c.gridSize, compact: true),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Fact(icon: Icons.repeat_rounded, text: '${c.rounds} rounds', color: AppColors.violet),
                          _Fact(
                            icon: Icons.grid_view_rounded,
                            text: '${c.gridSize}×${c.gridSize} · ${c.tileCount} tiles',
                            color: AppColors.blue,
                          ),
                          _Fact(icon: Icons.timer_rounded, text: '${c.memoryLabel} to memorize', color: AppColors.mint),
                          const SizedBox(height: 4),
                          const Text(
                            'Same boards for everyone today.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: record == null ? 'Play' : 'Practice',
                icon: Icons.play_arrow_rounded,
                gradient: AppGradients.sunrise,
                onPressed: () => Nav.playDaily(context),
              ),
              const SizedBox(height: 10),
              Text(
                record == null
                    ? 'Your first attempt today is your official score.'
                    : 'Official score recorded. Practice won\'t change it.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ScoreCard(
                      label: "Today's score",
                      value: record == null ? '—' : formatNumber(record.score),
                      sub: record == null ? 'Not played yet' : '${record.accuracy.round()}% accuracy',
                      color: AppColors.violet,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ScoreCard(
                      label: 'Best score',
                      value: state.progress.bestDailyScore == 0 ? '—' : formatNumber(state.progress.bestDailyScore),
                      sub: 'All time',
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.label, required this.value, required this.sub, required this.color});
  final String label, value, sub;
  final Color color;

  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption(label),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
        ),
        Text(
          sub,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ],
    ),
  );
}
