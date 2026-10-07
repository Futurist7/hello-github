import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/models/tile_position.dart';
import '../game/widgets/spatial_board.dart';
import '../state/app_state.dart';
import '../ui/components.dart';
import 'game_screen.dart';
import 'home_shell.dart';

/// First-launch "how to play". The button goes straight into level 1.
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  static final _pattern = {const TilePosition(0, 1), const TilePosition(1, 3), const TilePosition(3, 0)};

  Future<void> _done(BuildContext context, {required bool play}) async {
    final state = AppScope.read(context);
    await state.markTutorialSeen();
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    final home = gameRoute<void>(context, (_) => const HomeShell());
    // Created once so the patterns are fixed for the session.
    final spec = Sessions.level(1);
    final firstSession = play ? gameRoute<void>(context, (_) => GameScreen(spec: spec)) : null;
    nav.pushReplacement(home);
    // Home stays underneath so finishing the session lands there.
    if (firstSession != null) nav.push(firstSession);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotionOf(context, AppScope.of(context).settings.reducedMotion);
    var i = 0;
    Widget enter(Widget child) => Entrance(
      delay: Duration(milliseconds: 90 * i++),
      enabled: !reduced,
      child: child,
    );
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 24),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _done(context, play: false),
                          child: const Text('Skip Tutorial', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      enter(
                        const Text(
                          'How to play',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      enter(
                        const Text(
                          'Each level is 10 quick rounds.',
                          style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 22),
                      enter(
                        _Step(
                          number: 1,
                          text: 'Remember the highlighted tiles. You have 5 seconds or less.',
                          board: SpatialBoard(gridSize: 4, activeTiles: _pattern, compact: true),
                          color: AppColors.violet,
                        ),
                      ),
                      enter(
                        _Step(
                          number: 2,
                          text: 'The board clears.',
                          board: const SpatialBoard(gridSize: 4, compact: true),
                          color: AppColors.blue,
                        ),
                      ),
                      enter(
                        _Step(
                          number: 3,
                          text: 'Tap the positions where you remember them.',
                          board: SpatialBoard(gridSize: 4, selectedTiles: _pattern, compact: true),
                          color: AppColors.coral,
                        ),
                      ),
                      enter(
                        const _Step(
                          number: 4,
                          text: 'Score 80% or more across the 10 rounds to move up a level.',
                          icon: Icons.trending_up_rounded,
                          color: AppColors.mint,
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Got it',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => _done(context, play: true),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, required this.color, this.board, this.icon});
  final int number;
  final String text;
  final Color color;
  final Widget? board;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GameCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 78,
            child: board != null
                ? ExcludeSemantics(child: board)
                : Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: color, size: 36),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Caption('Step $number', color: color),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
