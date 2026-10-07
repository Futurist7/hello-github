import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Flame-powered celebration: a burst of glowing tiles behind the results.
///
/// The board itself is plain Flutter widgets (better semantics and touch
/// handling); Flame is used where a particle system adds real value.
class CelebrationGame extends FlameGame {
  CelebrationGame({required this.intensity, int? seed}) : _random = Random(seed);

  /// 0–1: how big the burst is.
  final double intensity;
  final Random _random;

  static const _colors = [
    AppColors.active,
    AppColors.activeDeep,
    AppColors.correct,
    AppColors.selected,
    AppColors.star,
  ];

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    final count = (24 + 56 * intensity).round();
    final origin = Vector2(size.x / 2, size.y * 0.28);
    add(
      ParticleSystemComponent(
        position: origin,
        particle: Particle.generate(
          count: count,
          lifespan: 1.6,
          generator: (i) {
            final angle = -pi / 2 + (_random.nextDouble() - 0.5) * pi * 1.6;
            final speed = 160 + _random.nextDouble() * 260;
            final side = 6 + _random.nextDouble() * 8;
            final color = _colors[_random.nextInt(_colors.length)];
            final spin = (_random.nextDouble() - 0.5) * 8;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 380),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final fade = (1 - particle.progress).clamp(0.0, 1.0);
                  final paint = Paint()..color = color.withValues(alpha: fade);
                  canvas.save();
                  canvas.rotate(spin * particle.progress);
                  canvas.drawRRect(
                    RRect.fromRectAndRadius(
                      Rect.fromCenter(center: Offset.zero, width: side, height: side),
                      Radius.circular(side * 0.25),
                    ),
                    paint,
                  );
                  canvas.restore();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Non-interactive overlay that plays [CelebrationGame] once.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.intensity});
  final double intensity;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late final CelebrationGame _game = CelebrationGame(intensity: widget.intensity);

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(child: GameWidget(game: _game)),
  );
}
