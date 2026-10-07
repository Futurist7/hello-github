import 'dart:math';

import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/logic/level_manager.dart';
import '../game/models/player_data.dart';
import '../game/widgets/score_display.dart';
import '../state/app_state.dart';
import 'home_shell.dart';

/// Vertical journey map of all levels.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  static const _rowHeight = 112.0;
  final _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final current = state.progress.currentLevel;
    if (!_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final target = (current - 2) * _rowHeight;
        _scroll.jumpTo(target.clamp(0, _scroll.position.maxScrollExtent));
      });
    }
    final reduced = reduceMotionOf(context, state.settings.reducedMotion);
    return Column(
      children: [
        const TabHeader(title: 'YOUR JOURNEY'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                '${state.progress.levelsCompleted} / ${LevelManager.levelCount} levels completed',
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 32, top: 8),
            itemCount: LevelManager.levelCount,
            itemExtent: _rowHeight,
            itemBuilder: (context, i) => _LevelNode(
              level: i + 1,
              progress: state.progress.levels[i],
              current: i + 1 == current,
              last: i == LevelManager.levelCount - 1,
              reducedMotion: reduced,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.progress,
    required this.current,
    required this.last,
    required this.reducedMotion,
  });

  final int level;
  final LevelProgress progress;
  final bool current;
  final bool last;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final config = LevelManager.config(level);
    // Gentle zig-zag so the path feels like a journey.
    final offset = sin(level * 0.9) * 0.28;
    final locked = !progress.unlocked;

    void open() {
      if (locked) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Complete level ${level - 1} to unlock level $level.')));
      } else {
        Nav.levelIntro(context, level);
      }
    }

    final status = locked
        ? 'locked'
        : progress.completed
        ? 'completed, ${progress.stars} stars, best score ${progress.bestScore}'
        : current
        ? 'current level'
        : 'unlocked';

    return Semantics(
      button: true,
      label: 'Level $level, $status',
      onTap: open,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: open,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              // Path runs just left of centre so the labels fit on the right.
              final base = w / 2 - 24;
              final shift = max(0.0, w / 2 - 64);
              final cx = base + offset * shift;
              final nextCx = base + sin((level + 1) * 0.9) * 0.28 * shift;
              const cy = 40.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (!last)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PathPainter(
                          from: Offset(cx, cy),
                          to: Offset(nextCx, cy + box.maxHeight),
                          done: progress.completed,
                        ),
                      ),
                    ),
                  Positioned(
                    left: cx - 32,
                    top: cy - 32,
                    child: _Bubble(
                      level: level,
                      locked: locked,
                      completed: progress.completed,
                      current: current,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                  Positioned(
                    left: cx + 32 + 12,
                    top: cy - 26,
                    width: 120,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${config.gridSize}×${config.gridSize} · ${config.tileCount} tiles',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: locked ? AppColors.textMuted : AppColors.textSecondary,
                          ),
                        ),
                        if (progress.unlocked) ...[
                          const SizedBox(height: 2),
                          StarRow(stars: progress.stars, size: 14),
                          if (progress.bestScore > 0)
                            Text(
                              'Best ${formatNumber(progress.bestScore)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  const _Bubble({
    required this.level,
    required this.locked,
    required this.completed,
    required this.current,
    required this.reducedMotion,
  });
  final int level;
  final bool locked, completed, current, reducedMotion;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Bubble old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.current && !widget.reducedMotion) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final Color fill = w.locked
        ? AppColors.surface
        : w.completed
        ? AppColors.correctDeep
        : AppColors.activeDeep;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: w.current
              ? [
                  BoxShadow(
                    color: AppColors.active.withValues(alpha: 0.25 + 0.35 * _c.value),
                    blurRadius: 12 + 14 * _c.value,
                    spreadRadius: 1 + 3 * _c.value,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: w.locked
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: w.completed
                      ? [AppColors.correct, AppColors.correctDeep]
                      : [AppColors.active, AppColors.activeDeep],
                ),
          color: w.locked ? fill : null,
          border: Border.all(color: w.locked ? AppColors.outline : Colors.white.withValues(alpha: 0.35), width: 2),
        ),
        alignment: Alignment.center,
        child: w.locked
            ? const Icon(Icons.lock_rounded, color: AppColors.textMuted)
            : Text(
                '${w.level}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF071226)),
              ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.from, required this.to, required this.done});
  final Offset from, to;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = done ? AppColors.correct.withValues(alpha: 0.5) : AppColors.outline
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dy = (to.dy - from.dy) / 2;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, from.dy + dy, to.dx, to.dy - dy, to.dx, to.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.done != done || old.from != from || old.to != to;
}
