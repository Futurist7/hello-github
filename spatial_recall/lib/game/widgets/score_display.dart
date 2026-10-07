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
    this.duration = const Duration(milliseconds: 1100),
    this.prefix = '',
    this.suffix = '',
    this.animate = true,
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final String prefix;
  final String suffix;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (!animate) return Text('$prefix${formatNumber(value)}$suffix', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix${formatNumber(v.round())}$suffix', style: style),
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
            Icon(Icons.star_rounded, size: size, color: i < stars ? AppColors.star : AppColors.outline),
        ],
      ),
    ),
  );
}

/// Rounded gradient progress bar that animates to new values.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.fraction, this.height = 10, this.gradient = AppGradients.brand});
  final double fraction;
  final double height;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.surfaceSoft),
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, f, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: f,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(height)),
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: streak > 0 ? AppColors.streak.withValues(alpha: 0.12) : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 19,
              color: streak > 0 ? AppColors.streak : AppColors.textMuted,
            ),
            const SizedBox(width: 3),
            Text(
              '$streak',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: streak > 0 ? AppColors.streak : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The game's mark: a 4×4 grid with lit tiles. Used on splash and home.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 72, this.lit = const {1, 10}, this.onDark = false});
  final double size;

  /// Indexes (row * 4 + column) of highlighted tiles.
  final Set<int> lit;

  /// White tiles for use on a coloured background.
  final bool onDark;

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
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cell * 0.28),
                    gradient: lit.contains(i) && !onDark ? AppGradients.brand : null,
                    color: lit.contains(i)
                        ? (onDark ? Colors.white : null)
                        : (onDark ? Colors.white.withValues(alpha: 0.22) : AppColors.tileEmpty),
                    boxShadow: lit.contains(i)
                        ? [
                            BoxShadow(
                              color: (onDark ? Colors.white : AppColors.violet).withValues(alpha: 0.4),
                              blurRadius: cell * 0.5,
                            ),
                          ]
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
