import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Shrinks slightly while pressed, then springs back: the tactile feel of
/// every tappable surface in the app.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Duration(milliseconds: _down ? 90 : 220),
          curve: _down ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Primary call to action: a gradient pill with a coloured glow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = AppGradients.brand,
    this.icon,
    this.height = 58,
  });

  final String label;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final glowColor = (gradient as LinearGradient).colors.last;
    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : AppColors.outline,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: enabled ? AppShadows.glow(glowColor) : const [],
        ),
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: enabled ? Colors.white : AppColors.textMuted,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 22, color: enabled ? Colors.white : AppColors.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary action: white pill with a hairline border.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.height = 54, this.color});
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onPressed,
    semanticLabel: label,
    child: Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.outline, width: 1.5),
      ),
      alignment: Alignment.center,
      child: ExcludeSemantics(
        child: Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary),
        ),
      ),
    ),
  );
}

/// Round icon button on a white disc.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 44,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Pressable(
      onTap: onPressed,
      scale: 0.9,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: AppShadows.soft),
        child: Icon(icon, size: size * 0.5, color: onPressed == null ? AppColors.textMuted : AppColors.textPrimary),
      ),
    ),
  );
}

/// Fades and slides its child in once, after [delay]. Used to stagger
/// cards on screen entry. Skipped with reduced motion.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.delay = Duration.zero, this.offset = 18, this.enabled = true});
  final Widget child;
  final Duration delay;
  final double offset;

  /// False (e.g. reduced motion) shows the child immediately.
  final bool enabled;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _c.value = 1;
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
    ),
  );
}

/// Circular progress ring with rounded caps.
class Ring extends StatelessWidget {
  const Ring({
    super.key,
    required this.progress,
    required this.size,
    this.stroke = 10,
    this.gradient = AppGradients.brand,
    this.track = AppColors.surfaceSoft,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Gradient gradient;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(progress.clamp(0.0, 1.0), stroke, gradient, track),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.stroke, this.gradient, this.track);
  final double progress;
  final double stroke;
  final Gradient gradient;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.gradient != gradient;
}

/// Small rounded label.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.color = AppColors.violet, this.filled = false});
  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: filled ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: filled ? Colors.white : color), const SizedBox(width: 5)],
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: filled ? Colors.white : color),
        ),
      ],
    ),
  );
}

/// Ten (or N) segments showing session progress; each finished round is
/// coloured by how it went.
class RoundProgress extends StatelessWidget {
  const RoundProgress({super.key, required this.total, required this.current, required this.results});

  final int total;

  /// Zero-based index of the round in play.
  final int current;

  /// Accuracy (0–100) of each finished round.
  final List<double> results;

  static Color colorFor(double accuracy) => accuracy >= 100
      ? AppColors.mint
      : accuracy >= 60
      ? AppColors.amber
      : AppColors.rose;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Round ${current + 1} of $total',
    child: ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                height: i == current ? 8 : 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i < results.length
                      ? colorFor(results[i])
                      : i == current
                      ? AppColors.violet
                      : AppColors.outline,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
