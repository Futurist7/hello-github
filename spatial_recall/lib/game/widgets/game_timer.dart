import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../../ui/components.dart';

/// Countdown ring for the memorise phase. It repaints every frame from the
/// round's stopwatch ([remaining]), so it drains perfectly smoothly, while
/// the rest of the screen stays untouched.
class MemoryTimer extends StatefulWidget {
  const MemoryTimer({super.key, required this.total, required this.remaining, this.size = 92});

  final Duration total;

  /// Remaining milliseconds right now.
  final int Function() remaining;
  final double size;

  @override
  State<MemoryTimer> createState() => _MemoryTimerState();
}

class _MemoryTimerState extends State<MemoryTimer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}))..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = widget.remaining();
    final total = widget.total.inMilliseconds;
    final seconds = ms / 1000;
    final urgent = ms <= 1000 && ms > 0;
    return Semantics(
      label: '${seconds.ceil()} seconds left',
      child: ExcludeSemantics(
        child: Ring(
          progress: total == 0 ? 0 : ms / total,
          size: widget.size,
          stroke: 8,
          gradient: urgent ? AppGradients.sunrise : AppGradients.brand,
          child: Text(
            seconds.toStringAsFixed(1),
            style: TextStyle(
              fontSize: widget.size * 0.27,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: urgent ? AppColors.coral : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
