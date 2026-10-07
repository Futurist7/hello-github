import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../game/models/tile_position.dart';
import '../game/widgets/spatial_board.dart';
import '../state/app_state.dart';
import 'game_screen.dart';
import 'home_shell.dart';

/// First-launch "how to play". GOT IT goes straight into level 1.
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  static final _pattern = {TilePosition(0, 1), TilePosition(1, 3), TilePosition(3, 0)};

  Future<void> _done(BuildContext context, {required bool play}) async {
    final state = AppScope.read(context);
    await state.markTutorialSeen();
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    final home = gameRoute<void>(context, (_) => const HomeShell());
    // Created once so the pattern is fixed for the round.
    final spec = Rounds.level(1);
    final firstRound = play ? gameRoute<void>(context, (_) => GameScreen(spec: spec)) : null;
    nav.pushReplacement(home);
    // Home stays underneath so finishing the round lands there.
    if (firstRound != null) nav.push(firstRound);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 32),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _done(context, play: false),
                          child: const Text('Skip Tutorial'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('HOW TO PLAY', style: text.headlineMedium),
                      const SizedBox(height: 28),
                      _Step(
                        number: 1,
                        text: 'Remember the highlighted tiles.',
                        board: SpatialBoard(gridSize: 4, activeTiles: _pattern, compact: true),
                      ),
                      _Step(
                        number: 2,
                        text: 'The board will disappear.',
                        board: const SpatialBoard(gridSize: 4, compact: true),
                      ),
                      _Step(
                        number: 3,
                        text: 'Then tap the positions where you remember them.',
                        board: SpatialBoard(gridSize: 4, selectedTiles: _pattern, compact: true),
                      ),
                      const SizedBox(height: 12),
                      Text("That's it.", style: text.titleLarge),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(onPressed: () => _done(context, play: true), child: const Text('GOT IT')),
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
  const _Step({required this.number, required this.text, required this.board});
  final int number;
  final String text;
  final Widget board;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GameCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox.square(dimension: 84, child: ExcludeSemantics(child: board)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Caption('Step $number', color: AppColors.active),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
