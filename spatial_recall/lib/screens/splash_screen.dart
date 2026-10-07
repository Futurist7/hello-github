import 'dart:async';

import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/widgets/score_display.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import 'tutorial_screen.dart';

/// Short branded splash with a little tile animation, then routes to the
/// tutorial (first launch) or home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _sequence = [
    {1},
    {1, 6},
    {1, 6, 11},
    {1, 6, 11, 12},
  ];
  int _step = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timer != null) return;
    final state = AppScope.read(context);
    final reduced = reduceMotionOf(context, state.settings.reducedMotion);
    if (reduced) {
      _step = _sequence.length - 1;
      _timer = Timer(const Duration(milliseconds: 500), _finish);
    } else {
      _timer = Timer.periodic(const Duration(milliseconds: 220), (t) {
        if (_step < _sequence.length - 1) {
          setState(() => _step++);
        } else {
          t.cancel();
          _timer = Timer(const Duration(milliseconds: 380), _finish);
        }
      });
    }
  }

  void _finish() {
    if (!mounted) return;
    final state = AppScope.read(context);
    Navigator.of(
      context,
    ).pushReplacement(gameRoute<void>(context, (_) => state.tutorialSeen ? const HomeShell() : const TutorialScreen()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.brand),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoMark(size: 104, lit: _sequence[_step], onDark: true),
            const SizedBox(height: 28),
            const Text(
              'Spatial Recall',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8),
            ),
            const SizedBox(height: 4),
            Text(
              'Train your spatial memory',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );
}
