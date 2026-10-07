import 'tile_position.dart';

/// The set of tiles the player has to memorise for one round.
class Pattern {
  Pattern({required this.gridSize, required Iterable<TilePosition> positions, this.seed})
    : positions = Set.unmodifiable(positions);

  final int gridSize;
  final Set<TilePosition> positions;
  final int? seed;

  int get tileCount => positions.length;
}
