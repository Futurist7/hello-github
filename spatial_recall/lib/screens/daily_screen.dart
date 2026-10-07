import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/widgets/score_display.dart';
import '../game/widgets/spatial_board.dart';
import '../state/app_state.dart';
import 'home_shell.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final challenge = state.todaysChallenge;
    final record = state.dailyRecordFor(challenge.key);
    final c = challenge.config;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const TabHeader(title: "TODAY'S CHALLENGE"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_months[challenge.date.month - 1]} ${challenge.date.day}',
                style: text.titleMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Chip('${c.gridSize} × ${c.gridSize}'),
                  const SizedBox(width: 8),
                  _Chip('${c.tileCount} tiles'),
                  const SizedBox(width: 8),
                  _Chip('${c.memorySeconds} seconds'),
                ],
              ),
              const SizedBox(height: 20),
              const Caption("Today's board", align: TextAlign.center),
              const SizedBox(height: 10),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
                  child: AspectRatio(
                    aspectRatio: 1,
                    // The pattern itself stays hidden until you play.
                    child: SpatialBoard(gridSize: c.gridSize, compact: true),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Everyone gets the same pattern today.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              GameCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Caption("Today's score"),
                          const SizedBox(height: 4),
                          Text(
                            record == null ? '—' : formatNumber(record.score),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                          ),
                          if (record != null)
                            Text(
                              '${record.accuracy.round()}% accuracy',
                              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Caption('Best score'),
                          const SizedBox(height: 4),
                          Text(
                            state.progress.bestDailyScore == 0 ? '—' : formatNumber(state.progress.bestDailyScore),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.star),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => Nav.playDaily(context), child: Text(record == null ? 'PLAY' : 'PRACTICE')),
              const SizedBox(height: 10),
              Text(
                record == null
                    ? 'Your first attempt today is your official score.'
                    : 'Official score recorded. Practice rounds won\'t change it.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}
