import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Large countdown listening only to [remainingMs], so ticking doesn't
/// rebuild the rest of the game screen. Pulses on the final 3 seconds.
class GameTimer extends StatefulWidget {
  const GameTimer({super.key, required this.remainingMs, required this.reducedMotion, this.compact = false});

  final ValueNotifier<int> remainingMs;
  final bool reducedMotion;
  final bool compact;

  @override
  State<GameTimer> createState() => _GameTimerState();
}

class _GameTimerState extends State<GameTimer> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  int _shown = -1;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.remainingMs,
      builder: (context, ms, _) {
        final seconds = (ms / 1000).ceil();
        if (seconds != _shown) {
          final first = _shown == -1;
          _shown = seconds;
          if (!first && seconds <= 3 && seconds > 0 && !widget.reducedMotion) {
            _pulse.forward(from: 0);
          }
        }
        final urgent = seconds <= 3;
        return Semantics(
          liveRegion: true,
          label: '$seconds seconds left',
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = _pulse.value;
                final scale = 1 + 0.14 * (t < 0.4 ? t / 0.4 : (1 - t) / 0.6);
                return Transform.scale(scale: scale, child: child);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seconds.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: widget.compact ? 44 : 56,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: urgent ? AppColors.selected : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: widget.compact ? 2 : 4),
                  const Caption('seconds'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
