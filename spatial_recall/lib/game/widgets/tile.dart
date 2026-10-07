import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum TileVisual { empty, active, selected, correct, wrong, missed }

/// One board tile. Animates when it lights up and when it clears.
class GameTile extends StatefulWidget {
  const GameTile({super.key, required this.visual, required this.reducedMotion});

  final TileVisual visual;
  final bool reducedMotion;

  @override
  State<GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<GameTile> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  /// The filled state currently drawn (kept while animating out).
  late TileVisual _fill = widget.visual;
  bool _leaving = false;

  static final _popIn = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
  ]);

  @override
  void initState() {
    super.initState();
    _c.value = 1;
    if (_isFilled(widget.visual) && !widget.reducedMotion) _animateIn();
  }

  static bool _isFilled(TileVisual v) => v != TileVisual.empty && v != TileVisual.missed;

  void _animateIn() {
    _leaving = false;
    _c.duration = const Duration(milliseconds: 200);
    _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(GameTile old) {
    super.didUpdateWidget(old);
    final v = widget.visual;
    if (v == old.visual) return;
    if (_isFilled(v)) {
      _fill = v;
      if (widget.reducedMotion) {
        _leaving = false;
        _c.value = 1;
      } else {
        _animateIn();
      }
    } else if (_isFilled(old.visual) && !widget.reducedMotion) {
      // Shrink and fade the old fill away.
      _leaving = true;
      _c.duration = const Duration(milliseconds: 240);
      _c.forward(from: 0).whenComplete(() {
        if (mounted && _leaving) setState(() => _fill = widget.visual);
      });
    } else {
      _leaving = false;
      _fill = v;
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final radius = BorderRadius.circular(box.maxWidth * 0.22);
        return Stack(
          fit: StackFit.expand,
          children: [
            _EmptyTile(radius: radius, missed: widget.visual == TileVisual.missed),
            if (_isFilled(_fill) && (_isFilled(widget.visual) || _leaving))
              AnimatedBuilder(
                animation: _c,
                builder: (context, child) {
                  final t = _c.value;
                  double scale, opacity;
                  if (_leaving) {
                    final e = Curves.easeIn.transform(t);
                    scale = 1 - 0.4 * e;
                    opacity = 1 - e;
                  } else {
                    scale = widget.reducedMotion ? 1 : _popIn.transform(t);
                    opacity = 1;
                  }
                  return Opacity(
                    opacity: opacity.clamp(0, 1),
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: _FilledTile(visual: _fill, radius: radius),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.radius, required this.missed});
  final BorderRadius radius;
  final bool missed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: radius,
      color: missed ? AppColors.violet.withValues(alpha: 0.08) : AppColors.tileEmpty,
      border: Border.all(
        color: missed ? AppColors.violet.withValues(alpha: 0.85) : AppColors.tileEmptyEdge,
        width: missed ? 2.4 : 1,
      ),
    ),
    child: missed
        ? FractionallySizedBox(
            widthFactor: 0.28,
            heightFactor: 0.28,
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.violet.withValues(alpha: 0.7)),
            ),
          )
        : null,
  );
}

class _FilledTile extends StatelessWidget {
  const _FilledTile({required this.visual, required this.radius});
  final TileVisual visual;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final (light, deep) = switch (visual) {
      TileVisual.active => (AppColors.active, AppColors.activeDeep),
      TileVisual.selected => (AppColors.selected, AppColors.selectedDeep),
      TileVisual.correct => (AppColors.correct, AppColors.correctDeep),
      TileVisual.wrong => (AppColors.wrong, AppColors.wrongDeep),
      _ => (AppColors.tileEmpty, AppColors.tileEmpty),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, deep]),
        boxShadow: [BoxShadow(color: deep.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: CustomPaint(painter: _GlyphPainter(visual)),
    );
  }
}

/// Small shape cues so results don't rely on colour alone.
class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.visual);
  final TileVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (s * 0.1).clamp(1.8, 4.5);
    final c = size.center(Offset.zero);
    final r = s * 0.17;
    switch (visual) {
      case TileVisual.correct:
        final path = Path()
          ..moveTo(c.dx - r, c.dy)
          ..lineTo(c.dx - r * 0.25, c.dy + r * 0.75)
          ..lineTo(c.dx + r * 1.05, c.dy - r * 0.7);
        canvas.drawPath(path, p);
      case TileVisual.wrong:
        canvas.drawLine(c + Offset(-r, -r), c + Offset(r, r), p);
        canvas.drawLine(c + Offset(r, -r), c + Offset(-r, r), p);
      case TileVisual.selected:
        canvas.drawCircle(c, r * 0.45, p..style = PaintingStyle.fill);
      default:
        // Highlight sheen on the active tile.
        final sheen = Paint()..color = Colors.white.withValues(alpha: 0.28);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.18, size.height * 0.14, size.width * 0.38, size.height * 0.12),
            Radius.circular(size.height * 0.06),
          ),
          sheen,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.visual != visual;
}
