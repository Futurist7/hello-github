import 'package:flutter/material.dart';

import '../../app/theme.dart';

String formatNumber(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Counts up to [value] once.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
    this.prefix = '',
    this.animate = true,
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final String prefix;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (!animate) return Text('$prefix${formatNumber(value)}', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix${formatNumber(v.round())}', style: style),
    );
  }
}

/// Row of five stars.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 28, this.max = 5});
  final int stars;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$stars of $max stars',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < stars ? AppColors.star : AppColors.textMuted.withValues(alpha: 0.6),
            ),
        ],
      ),
    ),
  );
}

/// Rounded XP progress bar.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.fraction, this.height = 12});
  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.surfaceHigh),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction.clamp(0.0, 1.0),
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.activeDeep, AppColors.active])),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Flame icon + streak count.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$streak day streak',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.streak.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 20,
              color: streak > 0 ? AppColors.streak : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: streak > 0 ? AppColors.streak : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The game's mark: a 4×4 grid with two lit tiles. Used on home and splash.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 72, this.lit = const {1, 10}});
  final double size;

  /// Indexes (row * 4 + column) of highlighted tiles.
  final Set<int> lit;

  @override
  Widget build(BuildContext context) {
    final cell = size / 4;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          for (var i = 0; i < 16; i++)
            Positioned(
              left: (i % 4) * cell,
              top: (i ~/ 4) * cell,
              width: cell,
              height: cell,
              child: Padding(
                padding: EdgeInsets.all(cell * 0.1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cell * 0.25),
                    gradient: lit.contains(i)
                        ? const LinearGradient(colors: [AppColors.active, AppColors.activeDeep])
                        : null,
                    color: lit.contains(i) ? null : AppColors.tileEmpty,
                    boxShadow: lit.contains(i)
                        ? [BoxShadow(color: AppColors.active.withValues(alpha: 0.5), blurRadius: cell * 0.5)]
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
