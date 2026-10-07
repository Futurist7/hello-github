import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/round_result.dart';
import '../models/tile_position.dart';
import 'tile.dart';

/// What the board is showing.
enum BoardView {
  /// Live play: [SpatialBoard.activeTiles] lit, [SpatialBoard.selectedTiles] marked.
  play,

  /// Player's answer marked right/wrong, missed tiles outlined.
  yourAnswer,

  /// The target pattern; tiles the player found are green.
  solution,
}

/// Reusable square tile grid that scales to its constraints.
class SpatialBoard extends StatelessWidget {
  const SpatialBoard({
    super.key,
    required this.gridSize,
    this.activeTiles = const {},
    this.selectedTiles = const {},
    this.interactive = false,
    this.onTileTap,
    this.view = BoardView.play,
    this.evaluation,
    this.reducedMotion = false,
    this.compact = false,
  });

  /// Board showing a finished round.
  factory SpatialBoard.review({
    Key? key,
    required int gridSize,
    required RoundEvaluation evaluation,
    required BoardView view,
    bool reducedMotion = false,
  }) => SpatialBoard(
    key: key,
    gridSize: gridSize,
    evaluation: evaluation,
    view: view,
    reducedMotion: reducedMotion,
    compact: true,
  );

  final int gridSize;
  final Set<TilePosition> activeTiles;
  final Set<TilePosition> selectedTiles;
  final bool interactive;
  final ValueChanged<TilePosition>? onTileTap;
  final BoardView view;
  final RoundEvaluation? evaluation;
  final bool reducedMotion;

  /// Tighter padding for small review boards.
  final bool compact;

  TileVisual visualFor(TilePosition p) {
    final e = evaluation;
    switch (view) {
      case BoardView.play:
        if (activeTiles.contains(p)) return TileVisual.active;
        if (selectedTiles.contains(p)) return TileVisual.selected;
        return TileVisual.empty;
      case BoardView.yourAnswer:
        if (e == null) return TileVisual.empty;
        if (e.selected.contains(p)) {
          return e.target.contains(p) ? TileVisual.correct : TileVisual.wrong;
        }
        return e.target.contains(p) ? TileVisual.missed : TileVisual.empty;
      case BoardView.solution:
        if (e == null || !e.target.contains(p)) return TileVisual.empty;
        return e.selected.contains(p) ? TileVisual.correct : TileVisual.active;
    }
  }

  static String _stateLabel(TileVisual v) => switch (v) {
    TileVisual.active => 'highlighted',
    TileVisual.selected => 'Selected',
    TileVisual.correct => 'correct',
    TileVisual.wrong => 'incorrect',
    TileVisual.missed => 'missed',
    TileVisual.empty => '',
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final pad = compact ? side * 0.035 : (side * 0.03).clamp(6.0, 18.0);
        final gap = (side * (compact ? 0.012 : 0.016)).clamp(1.5, 8.0);
        final inner = side - pad * 2;
        final cell = inner / gridSize;

        return SizedBox.square(
          dimension: side,
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(compact ? 18 : 30),
                boxShadow: compact ? AppShadows.soft : AppShadows.lifted,
              ),
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Stack(
                  children: [
                    for (var r = 0; r < gridSize; r++)
                      for (var c = 0; c < gridSize; c++)
                        Positioned(
                          left: c * cell,
                          top: r * cell,
                          width: cell,
                          height: cell,
                          child: _cell(TilePosition(r, c), gap),
                        ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cell(TilePosition p, double gap) {
    final visual = visualFor(p);
    final state = _stateLabel(visual);
    final tile = Padding(
      padding: EdgeInsets.all(gap / 2),
      child: GameTile(visual: visual, reducedMotion: reducedMotion),
    );
    final label = 'Row ${p.row + 1}, Column ${p.column + 1}';
    if (!interactive) {
      return Semantics(
        label: state.isEmpty ? label : '$label, $state',
        child: ExcludeSemantics(child: tile),
      );
    }
    // The whole cell (including the gap) is the touch target.
    return Semantics(
      button: true,
      selected: visual == TileVisual.selected,
      label: label,
      value: visual == TileVisual.selected ? 'Selected' : null,
      onTap: () => onTileTap?.call(p),
      child: ExcludeSemantics(
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTileTap?.call(p), child: tile),
      ),
    );
  }
}
